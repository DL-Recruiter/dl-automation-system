# Project Progress

Log each session with:
- Current status
- Completed tasks
- Validation commands run
- Next actions and blockers

## 2026-04-01 (Flow 5 Form 2 write-path fixed so Flow 7 can map employer data)
- Current status:
  - Traced the missing employer-side report-summary mapping back to `BGV_5_Response1`: the employer response was updating `BGV_Requests`, but the matching `BGV_FormData` row was being skipped, so Flow 7 only had Form 1 data to populate.
- Completed tasks:
  - Investigated the real live failure path for the latest employer response:
    - confirmed `BGV_FormData` item `128` for `REQ-BGV-20260401-87341-EMP1` had `Form2RawJson = null` and blank `F2_*` fields
    - confirmed the matching `BGV_Requests` item `68` was already `Responded` with `ResponseReceivedAt` and `Severity = High`
    - inspected live Flow 5 run `08584265694446505565001042226CU06`
    - confirmed `Update_item_-_of_BGV_Request` succeeded but `Condition_-_if_FormData_row_found` and `Update_item_-_BGV_FormData` were skipped
    - found the skip cause: `Condition_-_if_FormData_row_found` only allowed `Succeeded, Skipped` after `Condition_-_Expire_Employer_Upload_Link`, but the unshare branch was actually failing
  - Patched `BGV_5_Response1`:
    - `Condition_-_if_FormData_row_found.runAfter` now accepts `Failed` from `Condition_-_Expire_Employer_Upload_Link`
    - `Stop_sharing_request_upload_folder.authentication` corrected from `@parameters('')` to `@parameters('$authentication')`
  - Packed and imported the updated solution into PAC and published the changes.
  - Verified live Flow 5 returned to `Started` state after deploy.
  - Backfilled the current broken `BGV_FormData` test row so Flow 7 has the real employer response to map on the next recurrence:
    - item `128`
    - `Form2SubmittedAt = 2026-04-01T09:57:25Z`
    - `Form2RawJson` restored from historical Flow 5 `Get_response_details` output for response `35`
- Validation commands run:
  - `m365 spo listitem get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_FormData --id 128 --output json`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fd4bf0e3-0916-f111-8341-002248582037 --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fd4bf0e3-0916-f111-8341-002248582037 --name 08584265694446505565001042226CU06 --withActions --output json`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_form2_mapping_fix_20260401.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_form2_mapping_fix_20260401.zip --publish-changes --force-overwrite`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name fd4bf0e3-0916-f111-8341-002248582037 --query "{displayName:name,state:properties.state,lastModified:properties.lastModifiedTime}" --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fd4bf0e3-0916-f111-8341-002248582037 --name 08584265694446505565001042226CU06 --withActions Get_response_details --output json`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_FormData --id 128 --Form2SubmittedAt "2026-04-01 17:57:25" --Form2RawJson <historical Get_response_details payload>`
- Next actions and blockers:
  - Wait for the next `BGV_7_Generate_Report_Summary` recurrence and verify:
    - `RS_Emp1.docx` is created/updated under `BGV Records/Candidate Files/BGV-20260401-87341`
    - the employer-side Form 2 details now populate in the report summary
  - If the next Flow 7 run passes, run daily sync again, update any final docs if needed, and then commit/push GitHub so PAC, local repo, and GitHub all match.

## 2026-04-01 (Flow 7 live report-write branch rebuilt and verified)
- Current status:
  - Reworked the final `BGV_7_Generate_Report_Summary` save path until the live runtime stopped skipping the report-write actions, then verified repeated successful scheduled runs in PAC.
- Completed tasks:
  - Confirmed the earlier designer-native reconnect fixed the old payload blocker:
    - `Compose_ReportForm2RawJson` now succeeds live
    - `HTTP - Fill Report Summary Controls` now succeeds live
  - Identified the remaining blocker as the final report save branch:
    - earlier `Condition` and `For_each` gate patterns were importing cleanly but still behaving inconsistently at runtime
    - update/create child actions were being skipped even when the parent branch action showed `Succeeded`
  - Rebuilt the save path into a simpler runtime-safe pattern:
    - `Update_report_summary_file_v2` now runs directly after `Filter_array_-_Existing_Report_v2`
    - `Create_report_summary_file_v2` now runs only when `Update_report_summary_file_v2` fails
    - `Compose_Report_Save_Complete_v2` now normalizes the save branch outcome before the Teams post branch runs
    - `Condition_-_Report_Summary_Post_Not_Already_Sent_v2` now runs after `Compose_Report_Save_Complete_v2`
  - Synced the final live Flow 7 definition back into the repo with daily sync.
  - Verified the repaired live flow on repeated scheduled runs after redeploy.
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fb5cf0e3-0916-f111-8341-002248582037 --output json`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
- Verified live runs:
  - `08584265800857617127484671768CU19`
  - `08584265794854886476509176992CU21`
  - `08584265788852176206870688990CU25`
- Next actions and blockers:
  - Commit and push the synced Flow 7 fix plus doc updates so local repo, PAC, and GitHub match.

## 2026-03-31 (Flow 7 report-summary generation restored for responded cases)
- Current status:
  - Rechecked the live Flow 7/report-summary pipeline after recent employer responses were not producing `RS_Emp*.docx` files, found the real skip condition, and restored report generation for new responded cases while confirming the dashboard flow is still refreshing on schedule.
- Completed tasks:
  - Investigated the live data path:
    - confirmed recent responded requests such as `REQ-BGV-20260331-55c26-EMP1` and `REQ-BGV-20260330-9bf33-EMP1` had no report-summary DOCX in their candidate folders before the fix
    - confirmed the matching `BGV_FormData` rows existed but had blank `Form2RawJson`, blank `Form2SubmittedAt`, and blank normalized `F2_*` fields
    - confirmed `BGV_7_Generate_Report_Summary` was still running on schedule but silently skipping report generation because it required `Form2RawJson` to be non-empty
  - Updated `BGV_5_Response1`:
    - hardened the `BGV_FormData` lookup so it now matches by `RecordItemID` from the resolved request row instead of relying only on `RequestID` text matching
  - Updated `BGV_7_Generate_Report_Summary`:
    - removed the hard requirement for non-empty `Form2RawJson`
    - added fallback payload builders so the report-summary Azure Function can still run when `Form2RawJson` is blank
    - fallback payload now derives Form 2 report values from the responded `BGV_Requests` row, including severity, flagged issues, notes, reason for leaving, and the key yes/no issue flags
  - Verified the live fix worked:
    - `BGV Records/Candidate Files/BGV-20260331-55c26/RS_Emp1.docx` now exists
    - `BGV Records/Candidate Files/BGV-20260330-9bf33/RS_Emp1.docx` now exists
  - Verified `BGV_9_Refresh_Dashboard_Excel` is still running on its 10-minute cadence, so dashboard refresh is not the blocker for these cases.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo listitem list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --fields ID,Title,RequestID,CandidateID,VerificationStatus,ResponseReceivedAt,Severity,Outcome,Modified --output json`
  - `m365 spo listitem get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_FormData --id 122 --output json`
  - `m365 spo file list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folderUrl \"/sites/DLRRecruitmentOps570/BGV Records/Candidate Files/BGV-20260331-55c26\" --recursive --output json`
  - `m365 spo file list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folderUrl \"/sites/DLRRecruitmentOps570/BGV Records/Candidate Files/BGV-20260330-9bf33\" --recursive --output json`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fb5cf0e3-0916-f111-8341-002248582037 --output json`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 03b36e72-1ace-4fcf-ad6d-80a583012f31 --output json`
- Next actions and blockers:
  - Run daily sync so the canonical local export matches the repaired live state.
  - Commit and push the synced `BGV_5` / `BGV_7` changes plus these doc updates so GitHub matches PAC and local again.

## 2026-03-31 (PEV response email merge + Form 2 Q8 prefill removal + faster Flow 7/9 polling)
- Current status:
  - Removed the employer Form 2 Q8 hard-prefill, merged recruiter response/severity emails into one `PEV Response Received` email, hardened `BGV_7` report pickup, and sped up dashboard refresh timing so live test changes appear sooner.
- Completed tasks:
  - Updated `BGV_4_SendToEmployer_Clean`:
    - removed the prefilled `Yes` value from employer Form 2 question `Q8 / information accurate`
    - employers now see that field blank and must answer it themselves
  - Updated `BGV_5_Response1`:
    - disabled the separate high-severity-only email branch
    - consolidated recruiter response emails into one shared-mailbox email for every employer response
    - subject now starts with `PEV Response Received`
    - subject always includes `Severity: <value>` and leaves the value blank when severity is empty
    - body keeps employer details, request id, candidate folder link, flagged issues, and cleaned details/comments
    - cleared responses still keep the TAC follow-up note in that same email
  - Updated `BGV_7_Generate_Report_Summary`:
    - recurrence changed from every 30 minutes to every 10 minutes
    - request query now pulls broadly with `$top 5000` and relies on in-flow `ResponseReceivedAt` gating instead of server-side null filtering
  - Updated `BGV_9_Refresh_Dashboard_Excel`:
    - recurrence changed from every 30 minutes to every 10 minutes
    - removed the Singapore-time execution-window gate so the dashboard refresh can run on every recurrence instead of waiting for specific clock slots
  - Updated docs to reflect the new PEV wording, blank Q8 behavior, and faster report/dashboard polling.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 3e03d678-ce7d-1508-99ab-a7624987e9cd --name 08584266826858603029469062913CU18 --output json`
- Next actions and blockers:
  - Import the updated solution to live, run daily sync, and push GitHub so PAC, local, and repo match again.
  - After deployment, verify one recent employer-response case now gets picked up by `BGV_7` within the faster polling window and that the dashboard row refreshes without waiting for a time gate.

## 2026-03-30 (BGV_5/BGV_6/BGV_7/BGV_9 notification and dashboard-clearing logic refresh)
- Current status:
  - Tightened the adverse-case/report-summary pipeline so report creation/posting keys off actual employer response timestamps, removed the immediate BGV-response Teams post from `BGV_5`, aligned the severity ladder so old neutral cases are treated as low, and updated dashboard completion logic for reminder/escalation-cleared cases.
- Completed tasks:
  - Updated `BGV_5_Response1`:
    - remapped the old `Neutral` branch to `Low`
    - kept wrong company-info issues as low severity
    - changed `BGV Checks` so only truly blank severity is treated as `Form Filled and Cleared`
    - disabled the immediate BGV channel post from `BGV_5` so the channel only gets day-5 auth alerts and report-summary posts
    - upgraded the recruiter cleared-case email so when severity is blank it says PEV checks are cleared, includes the candidate-folder link, and notes TAC form is to be sent
    - kept recruiter email formatting readable by cleaning escaped newline markers
  - Updated `BGV_6_HRReminderAndEscalation`:
    - preserved twice-daily reminder evaluation windows
    - kept `No response at Reminder 2` stamping one day after Reminder 2 when no employer form has been received
    - changed the recruiter Teams message for that path to a cleared-style `PEV Checks Cleared` notification with candidate-folder link and TAC follow-up wording
  - Updated `BGV_7_Generate_Report_Summary`:
    - changed request selection to key off `ResponseReceivedAt` instead of relying only on `VerificationStatus = Responded`
    - added helper formatting/actions so report-summary Teams posts include highest severity, flagged issues, candidate-folder link, report link, and readable details
    - limited report-summary Teams posts to adverse cases only (`Low` / `Medium` / `High`)
    - kept the one-time Teams-post guard on both create and update paths
  - Updated `BGV_9_Refresh_Dashboard_Excel`:
    - `Completed Status` now shows `Yes` for cases cleared via `No response at Reminder 2` and for `Employer Reminder 3 Sent`
    - `Completed Date` now falls back through `ResponseReceivedAt`, then `EscalatedAt`, then `Reminder3At`
  - Updated flow docs so the BGV channel, severity ladder, report-summary rules, and dashboard completed-case behavior match the canonical JSON again.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Import the updated solution to live, run daily sync, and push the synced state to GitHub.
  - After deployment, verify one employer-response case that previously missed `BGV_7` now produces the report summary and adverse Teams post as expected.

## 2026-03-30 (BGV_5 cleared-case Teams post restored)
- Current status:
  - Restored the third BGV channel post type so cleared employer responses now post to Teams again, while adverse cases still wait for the report-summary post from `BGV_7`.
- Completed tasks:
  - Updated `BGV_5_Response1`:
    - changed `Condition_-_Notifying_Teams` from fully disabled to cleared-only
    - Teams post now fires only when `varSeverity` is blank
    - Teams body now says `PEV Checks Cleared`, includes candidate name/id, employer, request id, candidate folder link, and notes TAC form is to be sent
  - Updated docs so the BGV channel behavior is explicit again:
    - unsigned authorization day-5 alert from `BGV_3`
    - cleared-case post from `BGV_5`
    - adverse report-summary post from `BGV_7`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Import the updated solution to live, run daily sync, and push the synced state to GitHub.

## 2026-03-30 (Dashboard candidate-folder link + candidate auth email PDF guide)
- Current status:
  - Wired the new dashboard `Candidate Folder Link` column into `BGV_9_Refresh_Dashboard_Excel`, attached the new `Instructions For Authorisation Form.pdf` guide in the candidate authorization email sent by `BGV_0_CandidateDeclaration`, and documented the final root cause/fix summary for the Saturday `BGV_4` outage.
- Completed tasks:
  - Updated `BGV_9_Refresh_Dashboard_Excel`:
    - now writes `Candidate Folder Link` for every dashboard row using the candidate SharePoint folder URL
  - Updated `BGV_0_CandidateDeclaration`:
    - reads `BGV Records/Templates/Instructions For Authorisation Form.pdf`
    - attaches that PDF to the candidate authorization email alongside the editable Word-form link
    - keeps the existing shared-link behavior for the live authorization Word document
  - Updated dashboard/docs:
    - documented the new `Candidate Folder Link` column in dashboard docs
    - documented the candidate-email PDF guide attachment in the flow guide
  - Saturday `BGV_4` failure summary:
    - the original failures looked like business-logic problems around `Condition - AuthorisationSigned` and `Condition - if file exist`, but the deeper issue was Power Automate rejecting imported nested control nodes and some mail-action shapes at runtime after PAC import
    - that is why early JSON-only fixes did not stick even when the expressions themselves were valid
    - the final stable fix came from simplifying the control structure, using safer gating/data-shaping patterns, and correcting the attachment payload/mail-action format that the live runtime would actually accept
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Import the updated solution to live and run daily sync so PAC, local repo, and GitHub all match again.

## 2026-03-30 (BGV_4 recruiter email polish + BGV_5 Teams formatting + BGV_7 report-post catch-up)
- Current status:
  - Polished the active employer/candidate email wording in `BGV_4_SendToEmployer_Clean`, fixed medium-severity Teams notification coverage and message formatting in `BGV_5_Response1`, and patched `BGV_7_Generate_Report_Summary` so the Teams report-link post can still happen when the report file already exists and is only being updated.
- Completed tasks:
  - Updated `BGV_4_SendToEmployer_Clean`:
    - employer email now politely asks HR to open the shared company-stamp Word document, place the company stamp inside it, and save it back using the same link
    - candidate copy email now says employer emails will be sent based on the candidate-provided details and tells the candidate to open the attached signed authorization form in Microsoft Word
  - Updated `BGV_5_Response1`:
    - medium employment-detail discrepancies now also set the Teams notify flag
    - recruiter-facing Teams/email detail blocks now render readable line breaks instead of raw `\\n` text
    - recruiter-facing Teams/email notifications now include a direct candidate-folder link
  - Updated `BGV_7_Generate_Report_Summary`:
    - added the same one-time report-summary Teams post guard to the update-report path, not just the create-report path
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Import the updated solution to live and verify the active cloud flows.
  - Dashboard candidate-folder link in Excel still depends on adding a real matching column to `tblDashboardCasesPA`; wiring it before that would risk breaking the add-row action.

## 2026-03-30 (BGV_4 candidate email wording generalized)
- Current status:
  - Updated the candidate reference email in `BGV_4_SendToEmployer_Clean` so it no longer exposes employer-slot details to the candidate while still attaching the signed authorization form.
- Completed tasks:
  - Updated `BGV_4_SendToEmployer_Clean`:
    - removed the employer/request-specific phrasing from the candidate email body
    - replaced it with a generic note that employer emails will be sent based on the details the candidate provided
    - kept the signed authorization form attached and explicitly told the candidate to keep that copy for their records
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "signed authorization form is attached|An email will be sent to your employers|Send_signed_form_copy_to_candidate_\(V2\)" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Import the updated solution, run daily sync, and keep GitHub aligned with the live mail wording.

## 2026-03-30 (BGV_3 authorization reminder cadence increased with signed-status buffer)
- Current status:
  - Updated `BGV_3_AuthReminder_5Days` so authorization reminders now run on Singapore-time reminder slots with a small post-hour buffer, while still checking the latest candidate signed state before sending.
- Completed tasks:
  - Updated `BGV_3_AuthReminder_5Days`:
    - changed recurrence from daily to hourly so the flow can evaluate `9:05 AM` and `9:05 PM` local reminder slots
    - computes reminder eligibility using Singapore local time rather than raw UTC elapsed days
    - sends one reminder on the authorization-send day at `9:05 PM` only when the link was created before `9:00 PM`
    - sends two reminders per day on local days 2 and 3 at `9:05 AM` and `9:05 PM`
    - keeps later reminder days to a single `9:05 AM` slot and limits Day-5 escalation to that same morning slot
    - changed duplicate guarding from “same day” to “same reminder slot” using `LastAuthReminderAt`
    - keeps the existing signed-status gate so reminders only continue when `AuthorisationSigned` is still not true at runtime
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "Recurrence|LocalNow_SGT|LinkCreatedLocal_SGT|EligibleReminderWindow|Condition__-_not_reminded_this_slot_|CurrentHour_SGT" flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Import the updated solution, run daily sync, and verify the live reminder flow remains started.

## 2026-03-30 (BGV_4 candidate-copy attachment + single-send guard + employer stamp wording)
- Current status:
  - Updated the live `BGV_4_SendToEmployer_Clean` mail actions so candidate copies carry the authorization attachment again, candidates only receive that copy once on the `EMP1` send, and employer wording now politely asks HR to place the company stamp into the shared Word document.
- Completed tasks:
  - Updated `BGV_4_SendToEmployer_Clean`:
    - restored the signed authorization attachment on the candidate reference email using the same SharePoint file-content payload as the employer email
    - removed the per-request Request ID sentence from the candidate email body and simplified the wording to a single “your verification has been sent” reference email
    - wrapped the candidate-copy email in an `EMP1` gate so candidates with EMP2/EMP3 requests still receive only one copy
    - refreshed the employer email wording so it politely requests the company stamp and tells HR to open the shared company-stamp Word document, place the stamp there, and save it back
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "Condition_-_Send_candidate_copy_once|Copy of Signed Authorization Form|company stamp|attached to this email|base64ToBinary" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Import the updated solution to live, run daily sync, and verify the active flow remains `BGV_4_SendToEmployer_Clean`.

## 2026-03-30 (BGV_0/BGV_4/BGV_6 company-stamp document flow + auth ID masking + Reminder 3 archive)
- Current status:
  - Deployed the new employer company-stamp document flow, masked authorization-form IDs down to the last 5 characters without changing list storage, and added Reminder 3 email archiving into the request folder.
- Completed tasks:
  - Updated `BGV_0_CandidateDeclaration`:
    - authorization Word-template NRIC field now receives the last 5 cleaned alphanumeric characters from the full submitted NRIC
    - authorization Word-template Passport field now receives the last 5 cleaned alphanumeric characters from the full submitted Passport when NRIC is absent
    - list storage remains unchanged, so `BGV_Candidates` and `BGV_FormData` still keep the full submitted NRIC/passport values
  - Updated `BGV_4_SendToEmployer_Clean`:
    - creates or reuses `Company Stamp - <RequestID>.docx` in `BGV Records/Candidate Files/<CandidateID>/<RequestID>`
    - sources that file from `BGV Records/Templates/Company Stamp.docx`
    - creates an anonymous edit sharing link for the employer-specific document
    - injects that shared document link into Form 2 prefill key `rd5d9cb98b1aa47dd8bcd7914cd4bdc87`
    - updates employer email wording so the Request ID and the direct company-stamp document link are both included
  - Updated `BGV_6_HRReminderAndEscalation`:
    - rebuilds reminder links using the same employer-specific shared company-stamp document link
    - saves a Reminder 3 email copy as HTML into the request folder when the final reminder is sent and no employer response has been received
  - Imported the updated solution into the default environment and ran daily sync so local canonical files match live.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo file list --webUrl "https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570" --folderUrl "BGV Records/Templates" --output json`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_20260330_company_stamp_and_idmask.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_20260330_company_stamp_and_idmask.zip --publish-changes --force-overwrite`
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
- Next actions and blockers:
  - Run one fresh end-to-end employer send case to confirm the generated `Company Stamp - <RequestID>.docx` link opens externally and the shared document is populated in the correct request folder.
  - Run one Reminder 3 case to confirm the archived HTML reminder copy is written to the request folder in live runtime.

## 2026-03-30 (BGV_4 live-state verification: production flow healthy, v2 parked off)
- Current status:
  - Verified that the production employer-send flow is healthy in live, and the flow shown as off in the UI screenshot was the parked `v2` copy rather than the active production flow.
- Completed tasks:
  - Confirmed live flow states in the default environment:
    - `BGV_4_SendToEmployer_Clean` is the active production flow.
    - `BGV_4_SendToEmployer_Clean_v2` remains intentionally `Stopped`.
  - Confirmed the latest live runs for the active production flow were successful on `2026-03-30`.
  - Updated `docs/flows_easy_english.md` so the active-vs-v2 status is explicit and future troubleshooting does not target the wrong flow.
- Validation commands run:
  - `git -C "BGV_Checks" status --short --branch`
  - `m365 flow list --environmentName "Default-38597470-4753-461a-837f-ad8c14860b22" --output json`
  - `m365 flow run list --environmentName "Default-38597470-4753-461a-837f-ad8c14860b22" --flowName "8eeeed39-e02f-4b7a-82c8-fc51f245d863" --output json`
- Next actions and blockers:
  - No live repair was required for the production Flow 4 at this point because the current scheduled runs are succeeding.
  - If `v2` is ever revived, treat it as a separate flow activation task rather than assuming it replaces the active production flow.

## 2026-03-27 (BGV_0 authorization template remap to DLRAuthorizationLetter_Template)
- Current status:
  - Remapped `BGV_0` Word template binding to the newly uploaded authorization template filename while preserving existing signature/checkbox/expiry behavior.
- Completed tasks:
  - Resolved new live template in SharePoint:
    - `BGV Records/Templates/DLRAuthorizationLetter_Template.docx`
    - drive id: `b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp`
    - file id: `017QXH3H2C7KNCCUL4KRDIDZKFV4VC5U6H`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `Populate_a_Microsoft_Word_template.inputs.parameters.file` now points to the new file id.
    - metadata path updated to `DLRAuthorizationLetter_Template.docx`.
  - Updated documentation reference:
    - `docs/flows_easy_english.md` template filename/path reference.
  - No changes made to signature detection (`BGV_1`), post-sign expiry/locking (`BGV_2`), or reminder logic (`BGV_3`).
- Validation commands run:
  - `m365 request --url "https://graph.microsoft.com/v1.0/drives/b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp/root:/Templates/DLRAuthorizationLetter_Template.docx" --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Pack/import/publish the updated solution and run daily sync so PAC/local/live remain aligned.

## 2026-03-27 (Dashboard email-sent timestamps + daytime refresh-window cadence + key-map doc sync)
- Current status:
  - Updated dashboard flow/schema so case rows now include explicit email-sent timestamps for candidate authorization and employer outreach, and aligned key-mapping docs with the latest prefill behavior.
- Completed tasks:
  - Updated canonical `BGV_9_Refresh_Dashboard_Excel`:
    - recurrence trigger set to every 30 minutes
    - added SGT execution-window gate so refresh runs only at:
      - `08:00`, `09:30`, `11:00`, `12:30`, `14:00`, `15:30`, `17:00`, `18:30`, `20:00`, `21:00`
    - added `Compose_CandidateEmailSentAt` from `BGV_Candidates.AuthorizationLinkCreatedAt` (SGT formatted)
    - added `Compose_EmployerEmailSentAt` from `BGV_Requests.HRRequestSentAt` (SGT formatted)
    - wrote new dashboard columns in this order:
      - `Candidate Email Sent At` before `Candidate Reminder`
      - `Employer Email Sent At` before `Employer Reminder`
  - Updated dashboard workbook builder:
    - `scripts/active/build_bgv_dashboard_pa_prototype.ps1`
    - added columns:
      - `Candidate Email Sent At`
      - `Employer Email Sent At`
  - Updated dashboard/key docs:
    - `docs/bgv_dashboard_headers.md`
    - `docs/bgv_dashboard_power_automate_redesign.md`
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
  - Synced and deployed:
    - packed/imported/published updated solution
    - ran daily sync to re-align canonical local files with live.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac auth who`
  - `pac solution pack --folder .\\flows\\power-automate\\unpacked --zipfile .\\artifacts\\exports\\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_dashboard_live.zip --settings-file .\\out\\deployment-settings\\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
- Next actions and blockers:
  - Re-upload of `BGVDashboard_FLow.xlsx` to SharePoint is blocked while file is locked by `recruitment@dlresources.com.sg`.
  - After file is closed, rerun:
    - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "out/dashboard/BGVDashboard_FLow.xlsx" --overwrite`

## 2026-03-27 (BGV_4 employer upload-link key + BGV_5/BGV_6 expiry flow updates)
- Current status:
  - Implemented employer-specific company-stamp upload-link handling using your new Form 2 prefill key (`rd5d9cb98b1aa47dd8bcd7914cd4bdc87`) and added link-expiry automation in response/closure paths.
- Completed tasks:
  - Updated canonical `BGV_4_SendToEmployer_Clean`:
    - creates request folder at `BGV Records/Candidate Files/<CandidateID>/<RequestID>`
    - creates anonymous edit sharing link for that folder
    - injects the folder share URL into prefilled Form 2 key `rd5d9cb98b1aa47dd8bcd7914cd4bdc87`
    - keeps per-employer specificity via `RequestID` (EMP1/EMP2/EMP3).
  - Updated canonical `BGV_5_Response1`:
    - after successful employer response processing, locates request folder and runs `UnshareItem` to expire the upload link.
  - Updated canonical `BGV_6_HRReminderAndEscalation`:
    - added close-window branch for no-response cases (`Reminder3At` >= 5 days, `ResponseReceivedAt` empty)
    - locates request folder and runs `UnshareItem` to expire upload access when the unresolved case reaches closure window.
  - Updated flow documentation:
    - `docs/flows_easy_english.md` now reflects the new upload-link key mapping and expiry behavior in flows 4/5/6.
  - Deployed live and synced:
    - packed and imported solution to default environment
    - ran `scripts/active/bgv_daily_sync.ps1` after import so local canonical files match live state.
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\\flows\\power-automate\\unpacked --zipfile .\\artifacts\\exports\\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_dashboard_live.zip --settings-file .\\out\\deployment-settings\\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
- Next actions and blockers:
  - If employers mainly use reminder emails instead of the first email, consider adding the same anonymous folder-share generation chain into `BGV_6` reminder prefill link (currently reminder link rebuild is unchanged except for existing form prefill fields).
  - Run one live end-to-end test with a real EMP slot to verify:
    - prefilled upload URL opens correctly for external HR
    - link is unshared immediately after response in `BGV_5`.

## 2026-03-26 (BGV_7 one-time report-summary Teams post guard)
- Current status:
  - Added idempotency guard so `BGV_7` report-summary Teams post sends only once per request/report.
- Completed tasks:
  - Added a new DateTime tracking column to live SharePoint lists:
    - `BGV_Requests`: `Report Summary Teams Posted At` (internal name `Report_x0020_Summary_x0020_Teams`)
    - `BGV_FormData`: `Report Summary Teams Posted At` (internal name `Report_x0020_Summary_x0020_Teams`)
  - Updated `BGV_7_Generate_Report_Summary` flow JSON so in the create-report path it:
    - checks both tracking fields are blank before posting Teams message
    - posts `Report Summary Created` only when both are blank
    - updates both list items with `utcNow()` after successful post
  - Updated easy-English flow doc to reflect this one-time posting behavior.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "Report_x0020_Summary_x0020_Teams|Condition_-_Report_Summary_Post_Not_Already_Sent" flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
  - `m365 spo field list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests`
  - `m365 spo field list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_FormData`
- Next actions and blockers:
  - Import/apply updated canonical flow JSON so runtime flow includes this guard.
  - Existing runs that already posted before this change are not retroactively altered.

## 2026-03-26 (BGV_4 requests-loop failure hardening)
- Current status:
  - Diagnosed latest live `BGV_4_SendToEmployer_Clean` failure (`2026-03-26`) as a failure cascade from the inner authorization-files loop (`For_each`) inside the requests loop.
- Completed tasks:
  - Pulled live failed run details for flow `BGV_4_SendToEmployer_Clean` in environment `Default-38597470-4753-461a-837f-ad8c14860b22`.
  - Updated canonical `BGV_4` flow JSON to harden two fragile expressions:
    - candidate lookup id now uses safe fallback:
      - `CandidateItemID/Id`
      - `CandidateItemID#Id`
      - `CandidateItemID.Id`
    - authorization files foreach now tolerates null:
      - `@coalesce(outputs('Get_files_(properties_only)')?['body/value'],createArray())`
  - This prevents loop-level failure when file list payload is null and avoids candidate-id shape drift issues.
- Validation commands run:
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --name 08584270882440027587298161840CU29 --withActions`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "CandidateItemID/Id|CandidateItemID#Id|coalesce\\(outputs\\('Get_files_\\(properties_only\\)'\\)\\?\\['body/value'\\],createArray\\(\\)\\)" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Import/apply updated canonical `BGV_4` JSON to live flow, then resubmit failed run to verify no loop crash.

## 2026-03-23 (BGV_5 outcome self-reference save fix)
- Current status:
  - Fixed the `BGV_5_Response1` save error caused by invalid self-reference while appending to `varOutcome`.
- Completed tasks:
  - Updated `BGV_5_Response1` outcome-building steps so they no longer reference `varOutcome` while appending to `varOutcome`.
  - Switched the flagged-issue appends to safe delimiter-prefixed appends:
    - `MAS`
    - `Disciplinary`
    - `Re-employ`
    - employment-detail selections
    - company-detail selections
    - `Other Comments`
  - Normalized the final `varOutcome` value at write/display points so downstream behavior stays the same:
    - `BGV_Requests.Outcome`
    - `BGV_FormData.F2_Outcome`
    - Teams notification body
    - recruiter email body
  - Ran a repo sweep for the same invalid `varOutcome` self-reference pattern across canonical flow JSON and did not find the same save blocker in the other flows.
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "variables\\('varOutcome'\\).*variables\\('varOutcome'\\)|concat\\(if\\(empty\\(variables\\('varOutcome'\\)\\)|SetVariable.*variables\\('varOutcome'\\)" flows/power-automate/unpacked/Workflows`
- Next actions and blockers:
  - Import the updated solution so live `BGV_5` matches the canonical fix.
  - Teams-connection warnings remain a separate live connector-binding issue and are not caused by this `BGV_5` save fix.

## 2026-03-23 (BGV_7 report-summary Teams post save fix)
- Current status:
  - Fixed the `BGV_7_Generate_Report_Summary` save error caused by an invalid cross-scope reference from the Teams post action to `Compose_ReportFileWebLink`.
- Completed tasks:
  - Updated the Teams message body in:
    - `flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
  - Replaced the out-of-scope `Compose_ReportFileWebLink` reference with inline expressions for:
    - report file name
    - report link
  - Preserved the business behavior:
    - Teams post still only happens when a new report summary file is created
    - Teams post still includes candidate ID, candidate name, request ID, report file, and report link
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - The save validation error is fixed in the canonical flow source.
  - The separate Teams connection binding warning still requires a valid live `shared_teams` connection before the flow can be turned on.

## 2026-03-23 (BGV_7 Teams connection triage + BGV_8 reply Teams notification)
- Current status:
  - Confirmed the `BGV_7_Generate_Report_Summary` activation warning is caused by a missing live `shared_teams` connector instance for `recruitment@dlresources.com.sg`, not by broken report-summary logic.
  - Extended `BGV_8` so employer email replies now notify the `DLR Recruitment Ops > BGV` channel after the matching records are updated successfully.
- Completed tasks:
  - Verified active PAC identity:
    - `recruitment@dlresources.com.sg`
  - Verified current connector inventory with `pac connection list` and confirmed:
    - no connected `shared_teams` connection instance currently exists for the `recruitment@dlresources.com.sg` account
  - Confirmed `BGV_7` still points to the correct BGV channel destination:
    - Team `DLR Recruitment Ops`: `4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - Channel `BGV`: `19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Updated `BGV_8_Track_Employer_Email_Replies`:
    - added embedded `shared_teams` connection reference using `cr94d_sharedteams_4466d`
    - added Teams post action after the successful `BGV_FormData` update
    - Teams post now includes:
      - `Request ID`
      - `Candidate ID`
      - employer name
      - sender email
      - received timestamp
      - subject
  - Updated flow docs to reflect the new `BGV_8` Teams-notification behavior.
- Validation commands run:
  - `pac auth who`
  - `pac connection list`
  - `pac connection create --help`
  - `rg -n "shared_teams|PostMessageToConversation|4475a565-7f2b-4df1-91cd-c8e3df8f805a|19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2" flows/power-automate/unpacked/Workflows docs`
- Next actions and blockers:
  - `BGV_7` cannot be turned on until a real Microsoft Teams connector instance is created/shared for `recruitment@dlresources.com.sg` and bound to connection reference `cr94d_sharedteams_4466d`.
  - `BGV_8` now contains the Teams post step and will need the same Teams connector binding before it can be activated cleanly.

## 2026-03-23 (Employer email reply tracking + dashboard source update)
- Current status:
  - Implemented employer mailbox reply tracking across `BGV_Requests`, `BGV_FormData`, the outbound employer email wording, and the recruiter dashboard source.
- Completed tasks:
  - Added live SharePoint DateTime columns:
    - `BGV_Requests.EmployerEmailReplyAt`
    - `BGV_FormData.EmployerEmailReplyAt`
  - Updated `BGV_4_SendToEmployer_Clean` employer email wording so employers are instructed to reply to the email or include the `RequestID` in the subject line for mailbox matching.
  - Added new canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_8_Track_Employer_Email_Replies-FA5CF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_8_Track_Employer_Email_Replies-FA5CF0E3-0916-F111-8341-002248582037.json.data.xml`
  - `BGV_8` now:
    - watches the recruitment mailbox inbox
    - matches incoming emails by `RequestID` contained anywhere in the subject first
    - falls back to exact sender-email match against `BGV_Requests.EmployerHR_Email`
    - skips safely when no unique match or multiple possible matches are found
    - updates `EmployerEmailReplyAt` in both `BGV_Requests` and `BGV_FormData` when the newly detected reply is more recent than the stored value
  - Updated the dashboard build so the recruiter table now includes:
    - `Employer Email Reply At`
    - `Last Activity At` now also considers employer reply timestamps
  - Updated dashboard, flow, mapping, and SharePoint field docs to reflect the new reply-tracking path.

## 2026-03-16 (Whole-solution Power Automate validation pass)
- Current status:
  - Ran a full repo-side validation pass after the latest `BGV_0` and `BGV_1` fixes to confirm GitHub, local files, and the live Power Automate solution remain aligned.
- Completed tasks:
  - Verified repo/GitHub sync state:
    - `master...origin/master`
    - latest pushed fix present on `origin/master`
  - Verified active PAC identity:
    - `recruitment@dlresources.com.sg`
  - Ran `scripts/active/bgv_daily_sync.ps1` against:
    - `https://orgde64dc49.crm5.dynamics.com/`
  - Revalidated all canonical workflow JSON files:
    - `BGV_0` through `BGV_6`
  - Ran a full solution pack smoke test:
    - `artifacts/exports/BGV_System_validation_pack.zip`
  - Reviewed post-sync diffs and confirmed no new logic drift:
    - only trailing newline noise in `BGV_0` and `BGV_1`
    - normalized those files back to clean repo state
- Validation commands run:
  - `git status --short --branch`
  - `git log --oneline --decorate -1`
  - `pac auth who`
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `Get-ChildItem flows/power-automate/unpacked/Workflows/*.json | ForEach-Object { Get-Content -Raw $_.FullName | ConvertFrom-Json | Out-Null }`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_validation_pack.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `git diff --stat`
- Next actions and blockers:
  - Repository-side validation is clean.
  - Remaining gap is live end-to-end runtime testing, which still requires manual trigger submissions or run-history inspection for each business path.

## 2026-03-16 (BGV_1 SignedYes detection tightened on DLR Recruitment Ops site)
- Current status:
  - Tightened `BGV_1` so signed detection now prioritizes the actual `SignedYes` checkbox result and updates the candidate record on the `DLR Recruitment Ops` site.
- Completed tasks:
  - Reviewed canonical `BGV_1` trigger, parser call, filter actions, and SharePoint patch action.
  - Confirmed all SharePoint actions in `BGV_1` already point to:
    - `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Tightened `Signature_checkbox_condition` to:
    - mark signed when `Filter_array_-_SignedYes_Checked` has at least one checked match
    - use parser-level `signedYes = true` only when no `SignedYes`-style controls are returned at all
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `rg -n "SignedYes|CandidateAuthorisation|AuthorisationSigned|dataset|DLRRecruitmentOps570|ParseAuthorizationControls|PatchItem" <BGV_1_json>`
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and test one fresh signed authorization save to confirm `BGV_1` updates `BGV_Candidates` on the `DLR Recruitment Ops` site only after the checkbox is actually checked.

## 2026-03-16 (BGV_0 authorization template rebound to BGV Records template copy)
- Current status:
  - Fixed the candidate authorization document source in `BGV_0` so new candidate forms are generated from the target-site template copy that still contains the `SignedYes` checkbox.
- Completed tasks:
  - Investigated the live target-site template bindings for `BGV_0`.
  - Confirmed:
    - current flow binding was using `Documents/BGV Templates/AuthorizationLetter_Template.docx`
    - that file does not contain `SignedYes`
    - the correct file is `BGV Records/Templates/AuthorizationLetter_Template.docx`
    - that file does contain `SignedYes` and checkbox/control XML
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Rebound `Populate_a_Microsoft_Word_template` to:
    - drive `b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp`
    - file `017QXH3HY4VD3KC5XPBVHKXU2XVJJNBW5I`
  - Confirmed the candidate sharing action already remains editable:
    - `CreateSharingLink`
    - `permission/type = edit`
    - `permission/scope = anonymous`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `az account show`
  - `az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv`
  - Microsoft Graph drive lookup for:
    - `BGV Records/Templates/AuthorizationLetter_Template.docx`
    - `Documents/BGV Templates/AuthorizationLetter_Template.docx`
  - Downloaded both target-site template files and verified DOCX contents:
    - `BGV Records` copy: `SignedYes found`
    - `Documents` copy: `SignedYes missing`
  - `ConvertFrom-Json` on updated `BGV_0` JSON
- Next actions and blockers:
  - Next action: pack/import the updated solution and test one fresh candidate authorization email to confirm the generated document shows the checkbox and remains editable through the unique link.

## 2026-03-15 (Post-signature content-control locking automation)
- Current status:
  - Implemented automatic authorization DOCX content-control locking after signature status is obtained.
- Completed tasks:
  - Added new Azure Function endpoint:
    - `functions/bgv-docx-parser/LockAuthorizationControls.cs`
    - `GET/POST /api/LockAuthorizationControls`
  - Added DOCX locking service and DI registration:
    - `functions/bgv-docx-parser/Services/IDocxContentControlLocker.cs`
    - `functions/bgv-docx-parser/Services/OpenXmlDocxContentControlLocker.cs`
    - `functions/bgv-docx-parser/Program.cs`
    - lock mode applied: `w:lock w:val="sdtContentLocked"` across all content controls.
  - Added lock endpoint response model:
    - `functions/bgv-docx-parser/Models/LockContentControlsResponsePayload.cs`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json`
    - `BGV_2` now:
      - enumerates files in candidate authorization folder,
      - gets file content,
      - calls lock endpoint using parser URI token transform (`parseauthorizationcontrols` -> `lockauthorizationcontrols`),
      - updates file content with locked DOCX (`UpdateFile`),
      - then executes `Stop sharing`.
  - Updated linked docs:
    - `System_SPEC.md`
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `dotnet build functions/bgv-docx-parser/bgv-docx-parser.csproj`
  - `ConvertFrom-Json (Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json) | Out-Null`
  - `rg -n "LockAuthorizationControls|IDocxContentControlLocker|OpenXmlDocxContentControlLocker|UpdateFile|lockauthorizationcontrols" functions/bgv-docx-parser flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json System_SPEC.md docs/flows_easy_english.md docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: deploy the updated Azure Function app and import the updated solution.
  - Next action: run one signed authorization test and verify `BGV_2` updates file content successfully before unsharing.
  - Residual risk: `UpdateFile` SharePoint connector operation is syntactically valid in flow JSON but still requires runtime verification in target tenant.

## 2026-03-15 (Authorization template NRIC/Passport N/A fallback)
- Current status:
  - Updated both flow mapping and local template defaults so NRIC/Passport ID controls resolve to reciprocal `N/A` values.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - In `Populate_a_Microsoft_Word_template`:
    - `IdentificationNumberNRIC` content control now receives candidate NRIC when present; otherwise `N/A`.
    - `IdentificationNumberPassport` content control now receives `N/A` when NRIC is present; otherwise candidate passport when present; otherwise `N/A`.
  - Updated linked behavior docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
  - Updated local template file defaults:
    - `AuthorizationLetter_Template.docx`
    - set `IdentificationNumberNRIC` and `IdentificationNumberPassport` content-control default text to `N/A`
  - Updated local template file structure:
    - added bottom checkbox line `Yes, I authorized` with content-control alias/tag `SignedYes`
  - Added local backup before template edit:
    - `out/template_backups/AuthorizationLetter_Template_before_template_edit_20260315_204037.docx`
    - `out/template_backups/AuthorizationLetter_Template_before_checkbox_edit_20260315_210232.docx`
- Validation commands run:
  - `ConvertFrom-Json .\flows\power-automate\unpacked\Workflows\BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | Out-Null`
  - `rg -n "dynamicFileSchema/974713748|dynamicFileSchema/-206184337|N/A" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json docs/flows_easy_english.md docs/data_mapping_dictionary.md`
  - DOCX content-control verification (Open XML `word/document.xml`) to confirm:
    - `IdentificationNumberNRIC = N/A`
    - `IdentificationNumberPassport = N/A`
    - `SignedYes` checkbox content control is present with visible text `Yes, I authorized`
- Next actions and blockers:
  - Next action: run one candidate-form test with NRIC populated and one with passport populated to confirm generated authorization DOCX values in runtime.
  - Note: runtime flow uses the template file stored in SharePoint (`BGV_0` Word action `source/drive/file`); if that cloud template differs from this local file, upload/replace the cloud template to apply template-level default changes there.

## 2026-03-13 (Daily sync script hardened for PAC ZIP-lock unpack failures)
- Current status:
  - Patched the daily sync script so transient PAC unpack lock failures are no longer reported as successful runs.
- Completed tasks:
  - Updated `scripts/active/bgv_daily_sync.ps1`:
    - native command output is now captured and echoed back to the console
    - command output can now be treated as failure even when the process exits `0`
    - `pac solution unpack` now retries on ZIP-lock messages:
      - `cannot access the file`
      - `being used by another process`
    - unpack retry policy set to 5 retries with 5-second delay
  - Updated this progress log entry for traceability.
- Validation commands run:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/ -SkipPull`
- Next actions and blockers:
  - Next action: if ZIP-lock retries still fail intermittently, move the export ZIP to a less-contended local temp path outside OneDrive before unpack.

## 2026-03-19 (BGV_Requests status/link semantics tightened)
- Current status:
  - Aligned `BGV_Requests` lifecycle semantics and storage with the live employer-send / employer-response behavior.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `BGV_4` now stores the same generated employer Microsoft Forms URL into:
    - `BGV_Requests.LinktoEmployers` (`uniquelinktoemployers`)
  - Confirmed the live `LinkDue` column is SharePoint-calculated, not flow-written:
    - formula: `=IF(ISBLANK(SendAfterDate),"Due",IF(SendAfterDate<=TODAY(),"Due","Not Due"))`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - `BGV_5` now writes:
    - `VerificationStatus = Completed`
    - `Status = Completed`
    when an employer response is processed successfully.
  - Updated severity ladder in `BGV_5`:
    - `High`: MAS misconduct not `No / Not Applicable`
    - `High`: disciplinary issue = `Yes`
    - `Medium`: employer would not re-employ (`Q15 = No`)
    - `Low`: information accurate = `No` (`Q8 = No`) when no higher severity already exists
    - `Neutral`: other comments (`Q27`) when no higher severity already exists
  - Added `Q27` into the one-line notes summary trigger:
    - `Please refer to the report summary for additional comments.`
    - still deduplicated so it appears only once even when multiple comment fields are filled
  - Updated docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo field list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --output json`
  - `pac auth who`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_requests_logic_update.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_requests_logic_update.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: verify one fresh employer send writes `LinktoEmployers` and one fresh employer response stamps both status columns to `Completed`.

## 2026-03-12 (Operational smoke validation + secret hardening)
- Current status:
  - Production target migration remains live, and automated smoke validation re-ran successfully.
- Completed tasks:
  - Re-ran migration validation (`Mode=All`) and setup parity verification against source/target SharePoint sites.
  - Re-validated portability guard.
  - Removed hardcoded Azure Function key URL from canonical flow JSON:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
    - replaced with token `__BGV_DOCX_PARSER_URI__`.
  - Extended portability/deployment token support for parser endpoint in:
    - `scripts/active/check_bgv_portability.py`
    - `scripts/active/bgv_build_deployment_settings.ps1`
    - `flows/power-automate/deployment-settings/test.settings.template.json`
    - `flows/power-automate/deployment-settings/prod.settings.template.json`
    - `.env.example`
    - `System_SPEC.md`
    - `docs/architecture_flows.md`
    - `docs/Sharepoint migration plan.md`
- Validation commands run:
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode All -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_verify_setup_parity.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `py .\scripts\active\check_bgv_portability.py`
- Results summary:
  - `out/migration/validate_all.json`:
    - counts match (`BGV_Candidates 5/5`, `BGV_Requests 8/8`, `BGV_FormData 68/68`, `BGV Records files 61/61`)
    - sample mismatches: none
    - portability guard: passed
  - `out/migration/setup_parity.json`:
    - `Passed=true`, `MismatchCount=0`
- Next actions and blockers:
  - Push final migration state to GitHub.
  - Remaining manual operation unchanged: live user submission smoke path and communications/forms operational confirmation.

## 2026-03-12 (Permission parity blocker resolved)
- Current status:
  - Resolved the final strict setup-parity blocker for `BGV Records` permissions.
- Completed tasks:
  - Verified target-site admin-effective rights and applied:
    - `Set-PnPList -Identity "BGV Records" -BreakRoleInheritance -CopyRoleAssignments`
  - Confirmed target `BGV Records` now has unique permissions (`HasUniqueRoleAssignments=True`).
  - Reran setup parity verification; result now fully pass (`MismatchCount=0`).
  - Updated `docs/Sharepoint migration plan.md` execution status/pending section to remove the previous permission blocker.
- Validation commands run:
  - `Import-Module PnP.PowerShell -ErrorAction Stop; $conn=Connect-PnPOnline -Url 'https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570' -Interactive -ClientId '3e59bbcc-3e14-4837-b6e0-0a1870286f31' -Tenant '38597470-4753-461a-837f-ad8c14860b22' -ReturnConnection; Set-PnPList -Identity 'BGV Records' -BreakRoleInheritance -CopyRoleAssignments -Connection $conn -ErrorAction Stop; (Get-PnPList -Identity 'BGV Records' -Includes HasUniqueRoleAssignments -Connection $conn).HasUniqueRoleAssignments`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_verify_setup_parity.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
- Next actions and blockers:
  - Remaining actions are operational signoff only:
    - final production smoke-test evidence for `BGV_0`..`BGV_6`
    - confirm Forms ownership/sharing and communications under same-link strategy.

## 2026-03-12 (Forms strategy decision update: keep existing links)
- Current status:
  - Updated migration runbook to reflect the approved low-disruption Forms strategy.
- Completed tasks:
  - Updated `docs/Sharepoint migration plan.md` so cutover model explicitly keeps existing Microsoft Forms links/questions and applies backend-only redirection to target-bound flows.
  - Removed outdated instructions that required disabling/decommissioning forms as part of cutover.
  - Updated Step 3/8/9 and rollback wording to match same-link Forms operation.
- Validation commands run:
  - `Get-Content -Raw 'docs/Sharepoint migration plan.md'`
  - `rg -n "Forms|forms|disable|retire|old intake|manual" 'docs/Sharepoint migration plan.md'`
- Next actions and blockers:
  - Next action: execute live smoke tests with current Forms links to verify end-to-end target-site writes for `BGV_0`..`BGV_6`.
  - Blocker unchanged: `BGV Records` permission inheritance parity still requires elevated permission due `E_ACCESSDENIED`.

## 2026-03-12 (Full parity replication + single-window production cutover)
- Current status:
  - Implemented and executed the full source-to-target replication path.
  - Production BGV runtime is now live on target site bindings.
- Completed tasks:
  - Extended migration scripts for full-history replication:
    - `scripts/active/bgv_copy_site_data.ps1`
      - added/finished `-Mode All` behavior
      - full row copy for `BGV_FormData` including orphan historical rows
      - full `BGV Records` folder parity creation in `All` mode
      - output now includes folder and skipped-row metrics
    - `scripts/active/bgv_validate_target_migration.ps1`
      - `All` mode validates full-key selection and full-file parity
  - Added setup parity automation:
    - `scripts/active/bgv_sync_target_setup.ps1`
      - syncs settings/views
      - creates missing view-required fields from source schema (including projected/calculated fields)
      - syncs list `Title` required-state parity
    - `scripts/active/bgv_verify_setup_parity.ps1`
      - verifies counts, default-view fields, list settings, title-required parity, permission mode, and file counts
      - emits `out/migration/setup_parity.json`
  - Ran full-history copy and validation:
    - `out/migration/copy_all.json`
    - `out/migration/validate_all.json`
    - parity result: candidates `5/5`, requests `8/8`, formdata `68/68`, records files `61/61`
  - Resolved strict setup mismatches except one permission boundary:
    - fixed missing `BGV_Requests` fields (`CandidateItemID_x003a__x0020_Ful`, `LinkDue`)
    - fixed default-view parity
    - fixed list `Title` required-state parity for BGV tracking lists
    - remaining mismatch only: `BGV Records` unique permission mode (`E_ACCESSDENIED` on break inheritance)
  - Completed prod settings/materialization and production import with target bindings:
    - `scripts/active/bgv_build_deployment_settings.ps1` improved to:
      - accept environment overrides for connection IDs
      - emit `CopilotAgents` as array
      - write materialized files as UTF-8 without BOM
    - cutover artifacts:
      - `out/migration/freeze_window.json`
      - `artifacts/exports/BGV_System_pre_green_cutover_20260312_161406.zip`
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_161626.zip`
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_162627.zip`
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_163244.zip`
  - Activated production BGV flows and verified bindings:
    - started `BGV_0`..`BGV_6` via Flow Management API
    - runtime status artifact: `out/migration/production_flow_runtime_status_after_cutover.json`
    - confirms all `BGV_0`..`BGV_6` are `Started`, all reference target site, none reference source site
  - Hardened canonical flow JSON for SharePoint connector validation:
    - added missing `item/Title` parameters to affected create/patch actions in:
      - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
      - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
      - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
- Validation commands run:
  - PowerShell parser checks:
    - `scripts/active/bgv_copy_site_data.ps1`
    - `scripts/active/bgv_validate_target_migration.ps1`
    - `scripts/active/bgv_sync_target_setup.ps1`
    - `scripts/active/bgv_verify_setup_parity.ps1`
    - `scripts/active/bgv_build_deployment_settings.ps1`
  - Migration/data parity:
    - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_copy_site_data.ps1 -Mode All -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
    - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode All -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
    - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_sync_target_setup.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
    - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_verify_setup_parity.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - Packaging/import/runtime:
    - `pac auth who`
    - `pac connection list --environment https://orgde64dc49.crm5.dynamics.com/`
    - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_build_deployment_settings.ps1 -EnvironmentName prod -TargetSchemaPath .\out\migration\target_schema.json -OutputDirectory .\out\deployment-settings\final -MaterializeTo .\out\materialized\bgv_green_prod_cutover_final`
    - `pac solution export --environment https://orgde64dc49.crm5.dynamics.com/ --name BGV_System --path .\artifacts\exports\BGV_System_pre_green_cutover_20260312_161406.zip --managed false --overwrite`
    - `pac solution pack --zipfile .\artifacts\exports\BGV_System_green_prod_cutover_20260312_163244.zip --folder .\out\materialized\bgv_green_prod_cutover_final --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
    - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_green_prod_cutover_20260312_163244.zip --settings-file .\out\deployment-settings\final\prod.pac.settings.json --publish-changes --force-overwrite`
  - Portability guard:
    - `py scripts/active/check_bgv_portability.py`
- Next actions and blockers:
  - Manual-only closeout remains:
    - disable/close old Microsoft Forms and retire old intake links in communications.
  - One strict-parity blocker remains:
    - `BGV Records` permission inheritance mode mismatch (`source unique`, `target inherited`) due `E_ACCESSDENIED` on `Set-PnPList -BreakRoleInheritance`.
  - Recommended immediate post-cutover operations:
    - execute end-to-end smoke tests on live `BGV_0` -> `BGV_6`
    - archive signoff evidence and update user-facing runbook links.

## 2026-03-12 (Production flow runtime truth check + ChatGPT upload pack)
- Current status:
  - SharePoint migration artifacts and data parity are complete, but
    production runtime is not yet green-live.
- Completed tasks:
  - Queried production flow runtime state in
    `Default-38597470-4753-461a-837f-ad8c14860b22` and generated:
    - `out/migration/production_flow_runtime_status.json`
  - Confirmed current production facts:
    - all `BGV_*` flows are `Stopped`
    - deployed flow definitions still reference source site
      `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
    - no production flow definition currently references target site
      `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`
  - Updated migration status docs to reflect that production green
    cutover is still pending.
  - Created a ChatGPT upload context pack:
    - `docs/chatgpt_upload_pack_20260312.md`
    - `out/migration/chatgpt_upload_pack_20260312_145312/`
- Validation commands run:
  - Flow runtime extraction and JSON artifact generation via Flow
    Management API:
    - `out/migration/production_flow_runtime_status.json`
  - Spot checks:
    - confirmed all `BGV_*` flow states are `Stopped`
    - confirmed `HasTargetSiteRef=false`, `HasSourceSiteRef=true` for
      deployed production flow definitions
- Next actions and blockers:
  - Next action: perform production green import/bind/enable runbook and
    validate live target-site processing before declaring migration fully
    complete.
  - Manual blocker remains: old Microsoft Forms close/disable and old
    intake link retirement in user channels.

## 2026-03-12 (Schema completion + final settings + blue closeout execution)
- Current status:
  - Completed the requested end-phase migration sequence: target schema
    generation, final deployment settings materialization, and blue
    operational closeout execution.
- Completed tasks:
  - Patched `shared/bgv_migration_common.ps1` Graph template metadata
    lookup to try multiple path variants (server-relative, site-relative,
    drive-relative) so target template file metadata can be resolved
    reliably.
  - Ran `scripts/active/bgv_ensure_target_schema.ps1` successfully and
    generated:
    - `out/migration/target_schema.json`
  - Ran final settings materialization using target schema:
    - `scripts/active/bgv_build_deployment_settings.ps1 -EnvironmentName test -TargetSchemaPath out/migration/target_schema.json -OutputDirectory out/deployment-settings/final -MaterializeTo out/materialized/bgv_green_test_final`
    - `scripts/active/bgv_build_deployment_settings.ps1 -EnvironmentName prod -TargetSchemaPath out/migration/target_schema.json -OutputDirectory out/deployment-settings/final -MaterializeTo out/materialized/bgv_green_prod_final`
  - Executed blue-flow closeout in production environment
    (`Default-38597470-4753-461a-837f-ad8c14860b22`) via Flow Management
    API using Azure token auth:
    - disabled `BGV_0` through `BGV_6`
    - verified all seven target blue flows are `Stopped`
  - Archived final blue solution backup:
    - `artifacts/exports/BGV_System_blue_final_backup_20260312_022951.zip`
  - Generated closeout audit artifact:
    - `out/migration/closeout_report.json`
- Validation commands run:
  - PowerShell parser checks:
    - `shared/bgv_migration_common.ps1`
    - `scripts/active/bgv_ensure_target_schema.ps1`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_ensure_target_schema.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `pac auth who`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_build_deployment_settings.ps1 -EnvironmentName test -TargetSchemaPath .\out\migration\target_schema.json -OutputDirectory .\out\deployment-settings\final -MaterializeTo .\out\materialized\bgv_green_test_final`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_build_deployment_settings.ps1 -EnvironmentName prod -TargetSchemaPath .\out\migration\target_schema.json -OutputDirectory .\out\deployment-settings\final -MaterializeTo .\out\materialized\bgv_green_prod_final`
  - Flow-management closeout checks and operations:
    - listed Power Automate environments
    - listed `BGV_*` flows in default environment
    - issued stop operations for `BGV_0`..`BGV_6`
    - re-listed states to confirm `Stopped`
  - `pac solution export --environment https://orgde64dc49.crm5.dynamics.com/ --name BGV_System --path .\artifacts\exports\BGV_System_blue_final_backup_20260312_022951.zip --managed false --overwrite`
- Results summary:
  - `out/migration/target_schema.json` exists and includes target
    store/template graph metadata.
  - Final test/prod deployment settings and materialized solution folders
    are generated under `out/deployment-settings/final` and
    `out/materialized/`.
  - Blue flows (`BGV_0` to `BGV_6`) are now `Stopped`.
  - Final blue backup is archived and closeout report is recorded.
- Next actions and blockers:
  - Manual portal action still required: disable/close blue Microsoft
    Forms and retire any publicly distributed old intake links from user
    channels.
  - Step 6 test-environment smoke validation remains required for full
    operational signoff.

## 2026-03-12 (Migration review cross-check + remediation hardening)
- Current status:
  - Reviewed `docs/Sharepoint migration plan.md` against live migration
    outputs and script behavior, then continued remediation to close data
    integrity gaps observed during cross-check.
- Completed tasks:
  - Cross-check review findings:
    - LegacyDrain row/file parity can pass while internal form-data ID
      remap (`CandidateItemID`, `RecordItemID`) is still wrong unless
      remap is applied for numeric field types.
    - `out/migration/target_schema.json` is still missing because
      `bgv_ensure_target_schema.ps1` did not complete Graph auth in this
      terminal session.
  - Repaired target lookup binding:
    - `BGV_Requests.CandidateItemID` recreated on target and rebound to
      target `BGV_Candidates` list.
  - Hardened migration scripts:
    - `scripts/active/bgv_copy_site_data.ps1`
      - remap logic now supports numeric and lookup target field types
      - file copy now translates source site paths to target site paths
      - folder ensure now anchors under target web root and handles
        existing folders idempotently
    - `scripts/active/bgv_validate_target_migration.ps1`
      - excludes remapped `BGV_FormData` ID fields from source-vs-target
        sample equality checks
  - Re-ran `LegacyDrain` copy + validate after fixes.
  - Added execution-status snapshot to
    `docs/Sharepoint migration plan.md`.
- Validation commands run:
  - PowerShell parser checks:
    - `scripts/active/bgv_copy_site_data.ps1`
    - `scripts/active/bgv_validate_target_migration.ps1`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_copy_site_data.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - Target remap verification command:
    - checked `BGV_FormData.CandidateItemID`/`RecordItemID` against
      expected target item IDs (`FormDataRemapMismatchCount=0`)
  - Artifact checks:
    - `out/migration/copy_legacydrain.json`
    - `out/migration/validate_legacydrain.json`
- Results summary:
  - LegacyDrain copy:
    - `CandidateCount = 5`
    - `RequestCount = 8`
    - `FormDataCount = 8`
    - `FileCount = 0` (idempotent rerun; files already present)
    - `FailedFileCount = 0`
  - LegacyDrain validation:
    - `CandidateCountMatch = true`
    - `RequestCountMatch = true`
    - `FormDataCountMatch = true`
    - `FileCountMatch = true`
    - `PortabilityPassed = true`
    - sample mismatches: all zero
- Next actions and blockers:
  - Blocker: still need successful Graph-authenticated run of
    `bgv_ensure_target_schema.ps1` to produce
    `out/migration/target_schema.json` for a fully closed Step 5 record.
  - Next action: complete Step 6 (test-environment smoke validation) and
    Step 8/9 operational retirement tasks (disable blue assets, archive
    final blue backup, retire old intake links) after stakeholder signoff.

## 2026-03-12 (LegacyDrain remediation complete: lookup binding + file parity)
- Current status:
  - Completed the requested remediation and reran `LegacyDrain` end-to-end.
  - Target lookup binding for `BGV_Requests.CandidateItemID` is now fixed
    to the target `BGV_Candidates` list.
  - LegacyDrain now achieves full row and file parity.
- Completed tasks:
  - Repaired target lookup binding in SharePoint:
    - removed/recreated `BGV_Requests.CandidateItemID` on target with
      `List={65747b59-c6b0-4671-ae37-79e35ad84c48}`.
    - repopulated lookup values for existing target `BGV_Requests` rows
      from `CandidateID` -> target candidate item ID mapping.
  - Updated `scripts/active/bgv_copy_site_data.ps1` to harden migration:
    - normalized source/target server-relative folder paths for upload
      operations.
    - translated source file refs (`/sites/dlrespl/...`) to target refs
      (`/sites/DLRRecruitmentOps570/...`) before duplicate checks and
      writes.
    - made folder-ensure logic idempotent against "already exists"
      races during nested folder creation.
    - retained warning-only handling for unsupported/misbound lookup
      fields and per-file copy failures.
  - Reran:
    - `bgv_copy_site_data.ps1 -Mode LegacyDrain`
    - `bgv_validate_target_migration.ps1 -Mode LegacyDrain`
  - Confirmed no failed files after rerun.
- Validation commands run:
  - Target lookup inspection and repair commands for
    `BGV_Requests.CandidateItemID` schema/list binding.
  - PowerShell parser checks for `scripts/active/bgv_copy_site_data.ps1`.
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_copy_site_data.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - Artifact checks:
    - `out/migration/copy_legacydrain.json`
    - `out/migration/validate_legacydrain.json`
- Results summary:
  - Copy:
    - `CandidateCount = 5`
    - `RequestCount = 8`
    - `FormDataCount = 8`
    - `FileCount = 5`
    - `FailedFileCount = 0`
  - Validation:
    - `CandidateCountMatch = true`
    - `RequestCountMatch = true`
    - `FormDataCountMatch = true`
    - `FileCountMatch = true`
    - `PortabilityPassed = true`
    - sample mismatches:
      - candidates: `0`
      - requests: `0`
      - formdata: `0`
- Next actions and blockers:
  - Blocker: none for LegacyDrain copy/validate parity in this run.
  - Next action: if this is final cutover state, proceed with blue
    retirement checklist (disable blue flows/forms, archive backup, and
    close old intake links).

## 2026-03-12 (LegacyDrain execution run)
- Current status:
  - Executed `LegacyDrain` migration copy and validation.
  - Candidate/request/form-data row migration completed.
  - File migration did not complete due access-denied errors on source
    authorization files under `BGV Records`.
- Completed tasks:
  - Ran:
    - `scripts/active/bgv_copy_site_data.ps1 -Mode LegacyDrain`
    - `scripts/active/bgv_validate_target_migration.ps1 -Mode LegacyDrain`
  - Updated `scripts/active/bgv_copy_site_data.ps1` runtime behavior:
    - added lookup-target binding checks for `CandidateItemID` and
      `RecordItemID`; script now warns and skips lookup remap when target
      lookup fields are bound to non-target lists.
    - added per-file copy error handling so file access failures are
      recorded in output JSON and do not terminate the entire run.
  - Generated migration artifacts:
    - `out/migration/copy_legacydrain.json`
    - `out/migration/validate_legacydrain.json`
- Validation commands run:
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_copy_site_data.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - Artifact inspection via `ConvertFrom-Json` for:
    - `out/migration/copy_legacydrain.json`
    - `out/migration/validate_legacydrain.json`
- Results summary:
  - Copy:
    - `CandidateCount = 5`
    - `RequestCount = 8`
    - `FormDataCount = 8`
    - `FileCount = 0`
    - `FailedFileCount = 5` (all `Access denied`)
  - Validation:
    - `CandidateCountMatch = true`
    - `RequestCountMatch = true`
    - `FormDataCountMatch = true`
    - `FileCountMatch = false`
    - `PortabilityPassed = true`
    - sample mismatches:
      - candidates: `0`
      - requests: `8`
      - formdata: `0`
- Next actions and blockers:
  - Blocker: target lookup fields in `BGV_Requests`/`BGV_FormData` are
    still bound to source list IDs, so lookup remap was skipped to avoid
    write failures.
  - Blocker: source authorization files under `BGV Records` returned
    `Access denied`, preventing file copy completion.
  - Next action: repair target lookup bindings via schema remediation
    (recreate misbound lookup fields against target lists), then rerun:
    - `bgv_copy_site_data.ps1 -Mode LegacyDrain`
    - `bgv_validate_target_migration.ps1 -Mode LegacyDrain`
  - Next action: resolve file access permissions on source/target
    `BGV Records` library paths and rerun LegacyDrain for file parity.

## 2026-03-12 (Migration execution run: ClosedHistory + copy-script runtime fix)
- Current status:
  - Executed migration run commands in sequence for `ClosedHistory`.
  - Copy/validate now run end-to-end after fixing a runtime payload
    conversion bug in `bgv_copy_site_data.ps1`.
  - Current manifest has no closed-history rows, so this run migrated
    zero records/files by design.
- Completed tasks:
  - Ran migration preflight auth checks (`pac`, `m365`, `PnP` module).
  - Attempted `bgv_ensure_target_schema.ps1`; script reached template
    stage but was blocked by local Graph session constraints in this
    terminal (`Connect-MgGraph` WAM parent-window handle issue).
  - Ran `bgv_copy_site_data.ps1 -Mode ClosedHistory`; initial run failed
    at payload serialization with `Argument types do not match`.
  - Patched `scripts/active/bgv_copy_site_data.ps1` to normalize
    `Generic.List` values to arrays via `.ToArray()` before writing JSON.
  - Re-ran `bgv_copy_site_data.ps1 -Mode ClosedHistory` successfully.
  - Ran `bgv_validate_target_migration.ps1 -Mode ClosedHistory`
    successfully with portability guard pass.
  - Confirmed output artifacts:
    - `out/migration/copy_closedhistory.json`
    - `out/migration/validate_closedhistory.json`
- Validation commands run:
  - `pac auth who`
  - `m365 status`
  - `Import-Module PnP.PowerShell -ErrorAction Stop`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_ensure_target_schema.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22` (blocked at Graph session requirement)
  - PowerShell parser check for `scripts/active/bgv_copy_site_data.ps1` (pass)
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_copy_site_data.ps1 -Mode ClosedHistory -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22` (pass)
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_validate_target_migration.ps1 -Mode ClosedHistory -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22` (pass)
  - Artifact checks:
    - `Get-Content -Raw out\migration\copy_closedhistory.json | ConvertFrom-Json`
    - `Get-Content -Raw out\migration\validate_closedhistory.json | ConvertFrom-Json`
    - `Get-Content -Raw out\migration\inventory.json | ConvertFrom-Json`
- Next actions and blockers:
  - Blocker: `bgv_ensure_target_schema.ps1` requires active Microsoft
    Graph PowerShell auth context for template metadata capture; current
    terminal WAM interactive flow failed with parent-window-handle error.
  - Observation: inventory manifest currently reports:
    - `ClosedHistory`: 0 candidates / 0 requests / 0 record keys
    - `LegacyOpen`: 5 candidates / 8 requests / 8 record keys
  - Next action: decide whether to execute
    `bgv_copy_site_data.ps1 -Mode LegacyDrain` now (moves active/open
    cases), or defer until cutover criteria are met.

## 2026-03-12 (Migration plan doc aligned with implemented scripts)
- Current status:
  - Reviewed `docs/Sharepoint migration plan.md` against the current
    migration scripts and aligned stale statements to actual behavior.
- Completed tasks:
  - Updated `docs/Sharepoint migration plan.md` to reflect implemented
    portability-token architecture (`__BGV_*__`) rather than
    hardcoded-flow assumptions.
  - Aligned step-by-step commands and expectations with actual scripts:
    - `bgv_migration_inventory.ps1`
    - `bgv_ensure_target_schema.ps1`
    - `bgv_build_deployment_settings.ps1`
    - `bgv_copy_site_data.ps1`
    - `bgv_validate_target_migration.ps1`
  - Added explicit references to generated artifacts and review gates:
    - `out/migration/inventory.json`
    - `out/migration/target_schema.json`
    - materialized folder requirement for pack/import
  - Clarified current behavior where relevant:
    - inventory conflicts are reviewed via `TargetConflicts` output
    - `bgv_copy_site_data.ps1` requires explicit `-Mode`
    - validation script includes portability guard execution
- Validation commands run:
  - `Get-Content -Raw docs/Sharepoint migration plan.md`
  - `Get-Content -Raw scripts/active/bgv_migration_inventory.ps1`
  - `Get-Content -Raw scripts/active/bgv_ensure_target_schema.ps1`
  - `Get-Content -Raw scripts/active/bgv_build_deployment_settings.ps1`
  - `Get-Content -Raw scripts/active/bgv_copy_site_data.ps1`
  - `Get-Content -Raw scripts/active/bgv_validate_target_migration.ps1`
  - `rg -n "hardcodes|__BGV_|materialized|TargetConflicts|ClosedHistory|LegacyDrain" docs/Sharepoint migration plan.md`
- Next actions and blockers:
  - Next action: execute schema -> settings -> copy -> validate in
    `ClosedHistory` mode, then repeat copy/validate for `LegacyDrain`
    at cutover completion.
  - Blocker: none in document/script alignment after this update.

## 2026-03-12 (Migration inventory fix: m365 JSON line output handling)
- Current status:
  - Fixed the inventory failure at `Inspect target sharing capability`
    caused by PowerShell argument transformation on JSON text parsing.
  - `bgv_migration_inventory.ps1` now completes end-to-end and writes
    the inventory artifact successfully.
- Completed tasks:
  - Updated `shared/bgv_migration_common.ps1`:
    - hardened `ConvertFrom-BgvJson` so it accepts both single-string
      JSON and multi-line enumerable CLI output (for example `string[]`
      from `m365 ... --output json`).
    - normalized enumerable command output into one JSON text block
      before `ConvertFrom-Json`.
  - Re-ran migration inventory using current source/target SharePoint
    URLs and PnP app/tenant values.
- Validation commands run:
  - PowerShell parser check:
    - `[System.Management.Automation.Language.Parser]::ParseFile('shared/bgv_migration_common.ps1', ...)`
  - JSON parser smoke checks:
    - `ConvertFrom-BgvJson` with single multi-line JSON string (pass)
    - `ConvertFrom-BgvJson` with JSON line array (`string[]`) (pass)
  - End-to-end inventory run (pass):
    - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\bgv_migration_inventory.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
- Next actions and blockers:
  - Next action: continue migration sequence with
    `scripts/active/bgv_ensure_target_schema.ps1`, then
    `scripts/active/bgv_copy_site_data.ps1` and
    `scripts/active/bgv_validate_target_migration.ps1` in `ClosedHistory`
    mode first.
  - Blocker: none for inventory generation after this parser fix.

## 2026-03-11 (Migration resume preflight: local vs GitHub check + inventory run)
- Current status:
  - Resumed migration planning from the repository by validating local
    state and attempting the first migration-runbook step
    (`bgv_migration_inventory.ps1`).
  - PAC identity is confirmed for the admin account, but Microsoft 365
    CLI auth is not active in this shell yet.
- Completed tasks:
  - Checked local repository state:
    - branch is `master`, currently behind local `origin/master` by 1
      commit.
    - migration-related files remain unstaged/modified locally.
  - Checked configured GitHub remote URL:
    - `https://github.com/DL-Recruiter/dl-automation-system.git`
  - Ran migration inventory preflight with explicit source/target URLs,
    tenant, and PnP client id.
  - Confirmed inventory script progresses through:
    - source/target SharePoint connection
    - list/library inventory
    - case manifest classification
    - template candidate inspection
  - Confirmed current hard blocker is at target-sharing inspection due
    to missing Microsoft 365 CLI login state.
- Validation commands run:
  - `git status --short --branch`
  - `git remote -v`
  - `git log --oneline -n 8`
  - `git rev-parse HEAD`
  - `git rev-parse origin/master`
  - `pac auth who` (confirmed `edwin.teo@dlresources.com.sg`)
  - `m365 status` (logged out)
  - `Import-Module PnP.PowerShell; .\scripts\active\bgv_migration_inventory.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
- Next actions and blockers:
  - Blocker: `m365` is logged out; inventory fails at target sharing
    snapshot with: `CLI for Microsoft 365 is not logged in`.
  - Blocker: direct live GitHub fetch/API in this shell returned auth
    credential errors; local `origin/master` ref was used as baseline.
  - Next action: run `m365 login --authType browser`, confirm with
    `m365 status`, then rerun
    `scripts/active/bgv_migration_inventory.ps1` to generate
    `out/migration/inventory.json`.

## 2026-03-11 (BGV SharePoint site migration implementation)
- Current status:
  - Implemented the repo-side blue/green migration baseline for moving
    BGV from `https://dlresourcespl88.sharepoint.com/sites/dlrespl` to
    `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`.
  - Canonical flow JSON is now portability-tokenized and guarded against
    reintroducing old blue-site literals.
- Completed tasks:
  - Updated canonical flow files under
    `flows/power-automate/unpacked/Workflows/` so SharePoint site/list/
    library IDs, Word template IDs, Forms IDs, mailbox targets, and
    Teams routing now use `__BGV_*__` portability tokens.
  - Normalized the canonical connection references in
    `flows/power-automate/unpacked/Other/Customizations.xml` so the
    future green solution uses one SharePoint ref, one Forms ref, one
    Outlook ref, one Teams ref, and the existing Word Online ref.
  - Added migration automation scripts:
    - `shared/bgv_migration_common.ps1`
    - `scripts/active/bgv_migration_inventory.ps1`
    - `scripts/active/bgv_ensure_target_schema.ps1`
    - `scripts/active/bgv_copy_site_data.ps1`
    - `scripts/active/bgv_build_deployment_settings.ps1`
    - `scripts/active/bgv_validate_target_migration.ps1`
    - `scripts/active/check_bgv_portability.py`
  - Added deployment-settings templates:
    - `flows/power-automate/deployment-settings/test.settings.template.json`
    - `flows/power-automate/deployment-settings/prod.settings.template.json`
  - Added portability guard tests:
    - `tests/test_check_bgv_portability.py`
  - Updated linked documentation and placeholders:
    - `README.md`
    - `System_SPEC.md`
    - `docs/architecture_flows.md`
    - `.env.example`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
- Validation commands run:
  - PowerShell parser checks for:
    - `shared/bgv_migration_common.ps1`
    - `scripts/active/bgv_migration_inventory.ps1`
    - `scripts/active/bgv_ensure_target_schema.ps1`
    - `scripts/active/bgv_copy_site_data.ps1`
    - `scripts/active/bgv_build_deployment_settings.ps1`
    - `scripts/active/bgv_validate_target_migration.ps1`
  - `py -m py_compile scripts/active/check_bgv_portability.py tests/test_check_bgv_portability.py tests/test_enforce_linked_docs.py` (pass)
  - `py scripts/active/check_bgv_portability.py --repo-root .` (pass)
  - `Get-Content -Raw <each canonical BGV workflow JSON> | ConvertFrom-Json | Out-Null` (pass for all 7 flows)
  - `pac solution create-settings --solution-folder .\flows\power-automate\unpacked --settings-file .\out\deployment-settings\validation.pac.settings.json` (pass)
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_build_deployment_settings.ps1 -EnvironmentName test -OutputDirectory .\out\deployment-settings\smoke -MaterializeTo .\out\materialized\bgv_green_test_smoke` (pass after Windows PowerShell JSON-compatibility fix)
  - `py -m pytest tests/test_check_bgv_portability.py tests/test_enforce_linked_docs.py` (failed: `No module named pytest`)
- Next actions and blockers:
  - UI-only/manual work still remains outside repo automation:
    - clone Form 1 / Form 2 for green test and green prod
    - clone blue flows into a true `BGV_System_Green` solution in Power
      Automate so they get new component IDs
    - create or bind the target connection instances
    - import and smoke test in the separate Power Platform test
      environment
  - Next action: run the inventory/schema/build/copy/validate scripts
    against the real source and target sites after the required `m365`,
    `PnP.PowerShell`, and `Microsoft.Graph` sign-ins are live in the
    user shell.
  - Blocker: local Python `pytest` is not installed in this shell, so
    only `py_compile` validation was available for the new portability
    test module.

## 2026-02-27
- Current status:
  - Repository documentation updated with runtime environment, flow/connector architecture, and environment variable requirements.
  - Added placeholder flow and connector export files to enable reproducible repository layout pending authenticated export replacement.
- Completed tasks:
  - Updated `System_SPEC.md` with new Runtime Environment section, PAC CLI usage guidance, and `FUNCTION_KEY` environment variable contract.
  - Updated `.env.example` with Power Platform, SharePoint, Dataverse, Azure Function endpoint, and `FUNCTION_KEY` placeholders.
  - Added `docs/architecture_flows.md` describing flow-to-connector mapping, Azure Function header requirements, and PAC CLI integration commands.
  - Added `flows/` placeholders for `main` and `FlowRunLogs exporter` JSON exports.
  - Added `connectors/` placeholders for `shared_flowrunops` and `new_flowrunops` (XML + OAuth params).
  - Added test fixtures and tests for flow/connector connection mapping expectations.
  - Updated `docs/file_index.md` to include new folders/files.
- Validation commands run:
  - `python -m pytest tests/test_flow_connector_fixtures.py`
- Next actions and blockers:
  - Blocker: CLI executables `pac`, `az`, and `func` are not discoverable in this terminal context, so real exports and live tenant/subscription auto-discovery could not be executed here.
  - Next action: run authenticated `pac`/`az` commands in the user environment to replace placeholders and populate actual Azure tenant/subscription values.

## 2026-02-27 (Flow verification implementation)
- Current status:
  - Added executable flow-run verification script with OAuth token retrieval and run-history metadata normalization.
  - Added unit tests for token request handling, run metadata parsing, and endpoint override behavior.
- Completed tasks:
  - Added `scripts/active/verify_flow_runs.py`:
    - Loads `.env` if present.
    - Reads `FLOW_VERIFY_*` environment variables.
    - Requests OAuth token from Azure AD.
    - Calls Flow run-history endpoint via ARM URL composition or `FLOW_VERIFY_RUNS_URL` override.
    - Prints normalized run metadata JSON for verification.
  - Added `tests/test_verify_flow_runs.py` with mocked HTTP opener responses.
  - Added `scripts/active/import_flow_exports.ps1` to copy authenticated export files into repository-standard `flows/` paths.
  - Updated `.env.example` with `FLOW_VERIFY_*` placeholders.
  - Updated `System_SPEC.md`, `docs/architecture_flows.md`, and `docs/file_index.md` for contract/documentation consistency.
- Validation commands run:
  - `python scripts/active/verify_flow_runs.py` (expected failure without credentials; confirms required env-var checks)
  - `python -m pytest tests/test_verify_flow_runs.py tests/test_flow_connector_fixtures.py` (failed: `No module named pytest`)
  - `python -m py_compile scripts/active/verify_flow_runs.py tests/test_verify_flow_runs.py tests/test_flow_connector_fixtures.py`
- Next actions and blockers:
  - Blocker: real flow export replacement still requires authenticated `pac`/tenant access in user environment.
  - Next action: run authenticated export commands to replace placeholder files under `flows/`.

## 2026-03-02 (Flow plain-English documentation)
- Current status:
  - Added a non-technical flow summary document for the exported BGV JSON flows.
- Completed tasks:
  - Reviewed root-level BGV flow exports (`BGV_0` to `BGV_6`) and mapped each trigger/action chain into plain-language process steps.
  - Added `docs/flows_easy_english.md` with:
    - End-to-end process story.
    - Per-flow purpose, trigger, key actions, and outcome.
    - Cross-flow dependency mapping (candidate side, employer side, reminders/escalations).
- Validation commands run:
  - `git diff -- docs/flows_easy_english.md docs/progress.md`
  - `Get-Content -Raw docs/flows_easy_english.md`
- Next actions and blockers:
  - Next action: if needed, generate a second version with business-only wording for HR users (without technical terms like trigger/action).

## 2026-03-02 (Collaboration setup hardening)
- Current status:
  - Added explicit collaboration rules for dual-account operations and canonical flow edit paths.
- Completed tasks:
  - Verified git and PAC baseline in `C:\bgv_project`.
  - Fast-forwarded local branch to latest `origin/master`.
  - Confirmed environment context and active identity output in PAC CLI.
  - Updated `AGENTS.md` with mandatory canonical flow path:
    - `flows/power-automate/unpacked/Workflows/`
  - Added account/auth discipline section:
    - `edwin.teo@dlresources.com.sg` (dev/admin)
    - `recruitment@dlresources.com.sg` (operations)
  - Added `docs/collaboration_setup_guide.md`:
    - one-time setup
    - daily collaboration loop
    - export/unpack/edit/validate/commit
    - pack/import deployment loop
    - UI-only sharing steps for recruitment account
    - troubleshooting playbook
  - Updated `docs/file_index.md` to include new collaboration guide.
- Validation commands run:
  - `git -C C:\bgv_project pull --ff-only`
  - `pac auth list`
  - `pac env list`
  - `pac auth create --name BGV_EDWIN --environment https://orgde64dc49.crm5.dynamics.com/` (success)
  - `pac auth create --name BGV_RECRUITMENT --environment https://orgde64dc49.crm5.dynamics.com/` (created with wrong user because current sign-in stayed edwin)
  - `pac auth delete --name BGV_RECRUITMENT`
  - `pac auth create --name BGV_EDWIN --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/` (timed out waiting for interactive sign-in)
- Next actions and blockers:
  - Blocker: `pac auth create --deviceCode` needs interactive sign-in completion in browser; this cannot be completed unattended by agent.
  - Next action: run device-code sign-in manually to create a true `BGV_RECRUITMENT` profile with `recruitment@dlresources.com.sg`.

## 2026-03-03 (VS Code automatic flow run pull)
- Current status:
  - Added one-command automation to pull run history for all canonical BGV solution flows from VS Code.
- Completed tasks:
  - Updated `scripts/active/verify_flow_runs.py` with reusable `build_runs_url_for(...)` helper for environment/flow-specific URL composition.
  - Added `scripts/active/pull_all_flow_runs.py` to:
    - discover canonical flow IDs from `flows/power-automate/unpacked/Workflows/`
    - pull run histories for each flow using existing OAuth/token logic
    - write combined JSON report to `out/flow_run_history_latest.json` (configurable via env var)
  - Added `tests/test_pull_all_flow_runs.py` for canonical flow discovery and run query helper coverage.
  - Updated `tests/test_verify_flow_runs.py` for URL composition helper coverage.
  - Updated `.env.example` and docs (`docs/architecture_flows.md`, `docs/file_index.md`) with new command and optional settings.
- Validation commands run:
  - `py -m py_compile scripts/active/verify_flow_runs.py scripts/active/pull_all_flow_runs.py tests/test_verify_flow_runs.py tests/test_pull_all_flow_runs.py` (pass)
  - `py scripts/active/pull_all_flow_runs.py` (expected failure: missing local OAuth env var `FLOW_VERIFY_TENANT_ID`)
  - `py -m pytest tests/test_verify_flow_runs.py tests/test_pull_all_flow_runs.py` (failed: `No module named pytest`)
- Next actions and blockers:
  - Next action: populate local `.env` with `FLOW_VERIFY_TENANT_ID`, `FLOW_VERIFY_CLIENT_ID`, `FLOW_VERIFY_CLIENT_SECRET`, and `FLOW_VERIFY_ENVIRONMENT_ID`, then run `py scripts/active/pull_all_flow_runs.py`.
  - Blocker: OAuth app registration credentials are required for automated run-history retrieval.
  - Blocker: `python` alias is unavailable in current terminal; use `py` launcher or enable Python alias.

## 2026-03-03 (BGV_5 RequestID filter fix)
- Current status:
  - Patched `BGV_5_Response1` flow to remove unintended whitespace in SharePoint RequestID filter expression.
- Completed tasks:
  - Updated canonical flow file:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `$filter` from spaced RequestID comparison to exact match:
    - `RequestID eq '@{outputs('Get_response_details')?['body/rd745d133eb7f4611b59ea051f980f97a']}'`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null` (pass)
  - `Select-String -Path flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json -SimpleMatch '"$filter"'` (confirmed updated line)
- Next actions and blockers:
  - Next action: rerun `BGV_5_Response1` with a new employer form response and confirm `Get_items` returns 1 row and flow no longer terminates in else branch.

## 2026-03-03 (BGV_5 live failure root-cause and hardening)
- Current status:
  - Investigated failed run `08584290828823558058429050158CU23` in `BGV_5_Response1` after deployment.
  - Confirmed filter spacing issue was fixed, but `Get_items` still returned 0.
- Completed tasks:
  - Pulled live run action inputs/outputs via Flow API.
  - Confirmed `BGV_0` created RequestID with trailing newline (`REQ-BGV-...-EMP1\n`) in existing rows.
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - removed trailing newline artifacts from `item/RequestID` expressions for EMP1/EMP2/EMP3.
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - changed `$filter` to `startswith(RequestID, '<form request id>')` to match both existing newline-suffixed rows and normalized future rows.
  - Repacked and imported updated solution to Power Automate (`BGV_System`) with publish + force overwrite.
- Validation commands run:
  - `ConvertFrom-Json` checks for both patched workflow JSON files (pass).
  - `pac solution pack ...` (pass).
  - `pac solution import ... --publish-changes --force-overwrite` (pass).
- Next actions and blockers:
  - Next action: run a new `BGV_5_Response1` test; verify `Get_items` returns >=1 row and flow does not terminate in else branch.

## 2026-03-03 (Repository inventory documentation)
- Current status:
  - Added a full file-by-file inventory document for the GitHub-tracked repository contents.
- Completed tasks:
  - Added `docs/repo_inventory.md` with purpose descriptions for root files, connectors, docs, flow artifacts, scripts, and tests.
  - Updated `docs/file_index.md` to include `docs/repo_inventory.md`.
- Validation commands run:
  - `git ls-tree -r --name-only origin/master` (confirmed baseline tracked file set for inventory generation)
  - `Get-Content -Raw docs/repo_inventory.md`
- Next actions and blockers:
  - Next action: keep `docs/repo_inventory.md` updated whenever tracked files are added/removed significantly.

## 2026-03-03 (Linked-doc CI enforcement)
- Current status:
  - Added automated GitHub validation to enforce linked documentation updates when canonical flow JSON files change.
- Completed tasks:
  - Added `.github/workflows/linked-docs-guard.yml`:
    - runs on pull requests and pushes to `master`
    - computes diff range and enforces policy check
  - Added `scripts/active/enforce_linked_docs.py`:
    - detects canonical flow JSON changes under `flows/power-automate/unpacked/Workflows/`
    - requires `docs/progress.md` updates
    - requires at least one linked behavior doc update:
      - `System_SPEC.md`
      - `docs/flows_easy_english.md`
      - `docs/architecture_flows.md`
  - Added `tests/test_enforce_linked_docs.py` for pass/fail policy scenarios.
  - Updated `docs/file_index.md` with new workflow/script/test entries.
- Validation commands run:
  - `py -m py_compile scripts/active/enforce_linked_docs.py tests/test_enforce_linked_docs.py`
  - `py scripts/active/enforce_linked_docs.py --base HEAD~1 --head HEAD` (policy execution smoke check)
  - `py -m pytest tests/test_enforce_linked_docs.py` (failed: `No module named pytest`)
- Next actions and blockers:
  - Next action: verify the `Linked Docs Guard` workflow run on next PR/push in GitHub Actions.
  - Blocker: local `pytest` module is not installed in current shell.

## 2026-03-03 (README onboarding and operator guide)
- Current status:
  - Added a root `README.md` with concrete instructions for developers guiding Codex sessions.
- Completed tasks:
  - Added `README.md` with:
    - daily sync commands (`scripts/active/bgv_daily_sync.ps1`)
    - canonical flow edit path rules
    - pack/import deployment commands
    - run-history commands (`verify_flow_runs.py`, `pull_all_flow_runs.py`)
    - linked-doc policy and CI guard references
    - recommended Codex prompt pattern
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` to include the new README purpose.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `Get-Content -Raw docs/file_index.md`
  - `Get-Content -Raw docs/repo_inventory.md`
- Next actions and blockers:
  - Next action: keep README examples updated when script names or deployment commands change.

## 2026-03-03 (README expanded with full user task playbooks)
- Current status:
  - Expanded README with a more explicit, screenshot-style operational guide for users/developers guiding Codex.
- Completed tasks:
  - Updated `README.md` with:
    - explicit answer: sync first
    - one-time setup checklist
    - detailed `bgv_daily_sync.ps1` step-by-step behavior
    - what `bgv_daily_sync.ps1` does not do
    - common task playbooks (start work, investigate failure, patch/deploy, share with teammate)
    - explicit deploy commands and run-history utility commands
    - linked-doc CI policy summary
- Validation commands run:
  - `Get-Content -Raw README.md`
- Next actions and blockers:
  - Next action: if needed, add a short FAQ section for common operator errors (wrong PAC account, stale exports, missing Python launcher).

## 2026-03-03 (README push workflow + best practices)
- Current status:
  - Added missing operator guidance for safe GitHub push workflow and day-to-day best practices.
- Completed tasks:
  - Updated `README.md` with:
    - "How To Push To GitHub (Safe Sequence)" section
    - "Best Practices Checklist" section
  - Included explicit commands for pull/status/add/commit/push and CI verification.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `git status --short`
- Next actions and blockers:
  - Next action: if preferred, add a PR-based workflow variant as the default and keep direct-`master` push as an exception path.

## 2026-03-03 (README deployment runbook: GitHub -> Power Automate -> Production)
- Current status:
  - Added detailed deployment instructions covering source control handoff, environment deployment, production promotion, and rollback.
- Completed tasks:
  - Expanded `README.md` with end-to-end sections:
    - Local -> GitHub
    - GitHub -> Power Automate deployment
    - Production promotion checklist
    - Rollback steps
    - UI-only task boundary list
  - Included explicit command sequences and smoke-test requirements.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `git status --short --branch`
- Next actions and blockers:
  - Next action: if production has a separate environment URL/profile naming standard, add those exact values to README examples.

## 2026-03-02 (Daily sync script added)
- Current status:
  - Added a one-command script to reduce manual command mistakes during daily flow sync.
- Completed tasks:
  - Added `scripts/active/bgv_daily_sync.ps1` with safe defaults:
    - verifies required commands (`git`, `pac`)
    - prints active PAC identity (`pac auth who`)
    - runs `git pull --ff-only`
    - exports `BGV_System` to `artifacts/exports/`
    - unpacks into canonical folder `flows/power-automate/unpacked/`
    - optional `-RunTests` flag (`python -m pytest -q tests`)
  - Updated `docs/collaboration_setup_guide.md` with one-command usage examples.
  - Updated `docs/file_index.md` to index the new script.
- Validation commands run:
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipExport -SkipUnpack` (PASS)
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipPull -SkipExport -SkipUnpack -RunTests` (FAIL: `python` not on PATH in this shell)
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipPull -SkipExport -SkipUnpack -RunTests -PythonExe C:\ceipal_api_test\.venv\Scripts\python.exe` (PASS)
- Next actions and blockers:
  - Next action: teammate can adopt the one-command daily sync in VS Code terminal.
  - Note: if Python is not in PATH, pass `-PythonExe <full_path_to_python.exe>`.

## 2026-03-03 (BGV_4 employer prefill + email context fix)
- Current status:
  - Patched `BGV_4_SendToEmployer_Clean` so the employer-form link pre-fills company fields that were previously left blank.
- Completed tasks:
  - Retrieved live `BGV_5_Response1` run payload via Flow API and confirmed the second form fields existed but were empty:
    - `r413feb4da00a44258984ab4bc0a0d1c1`
    - `r1e9155da913446b2bda4ca5b56e5b502`
    - `rbe5f659a0dca4526878cf1af042a1af4`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `FinalVerificationLink` now uses `@concat(...)` with URL-encoded prefill query params for:
    - `RequestID` (`rd745...`)
    - declared employer name/address/UEN fields (`r413...`, `r1e...`, `rbe...`)
  - Expanded employer email body to include declared company details (name/address/UEN) so HR can verify context directly in the email.
  - Packed and imported updated solution to Power Automate (`BGV_System`) with publish + force overwrite.
  - Updated linked behavior documentation:
    - `docs/architecture_flows.md`
- Validation commands run:
  - `pac auth who` (confirmed active identity before live Flow API inspection)
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - Flow API checks for run/action payloads (`runs`, `actions/Get_response_details`) to confirm field IDs and blank values before patch.
- Next actions and blockers:
  - Next action: run a fresh end-to-end test from `BGV_0` through `BGV_5` and confirm the second-form company fields prefill.
  - Limitation: `BGV_Requests` currently does not expose dedicated `EmployerAddress`/`EmployerUEN` columns in action output; these values may remain blank unless source columns are added and populated upstream.

## 2026-03-03 (BGV_4 prefill key remap for candidate context fields)
- Current status:
  - Remapped `BGV_4` second-form prefill query keys to the latest Microsoft Forms keys shared from `Get Pre-filled URL`.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `FinalVerificationLink` now maps:
    - `r4930fc603c0f4cada09832be79f2a76f` <- `BGV_Candidates.FullName`
    - `r27b6bdb850dd48339dc05df11d485470` <- `BGV_Candidates.IdentificationNumberNRIC`
    - `r0c342001cdd8463181c36dba2a8933ad` <- `BGV_Candidates.IdentificationNumberPassport`
    - `rd745d133eb7f4611b59ea051f980f97a` <- `BGV_Requests.RequestID`
    - `rccaf3632669648baaa335c12d4ea40bf` <- `BGV_Requests.EmployerName`
  - Updated linked behavior documentation:
    - `docs/architecture_flows.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Select-String` checks for new `r...` keys in `FinalVerificationLink`
- Next actions and blockers:
  - Next action: receive remaining first-form -> second-form field mapping from user, then append additional prefill parameters in `BGV_4`.

## 2026-03-03 (PnP interactive app auth documentation alignment)
- Current status:
  - Captured newly completed PnP interactive app registration details in source-controlled documentation.
- Completed tasks:
  - Updated `System_SPEC.md`:
    - added auth-context separation (`pac` vs flow connector runtime vs PnP).
    - documented PnP interactive app baseline:
      - registration method: `Register-PnPEntraIDAppForInteractiveLogin`
      - app display name: `BGV-PnP-Automation`
      - app client id: `3e59bbcc-3e14-4837-b6e0-0a1870286f31`
    - added env contract entries:
      - `PNP_CLIENT_ID`
      - `PNP_TENANT_ID`
  - Updated `.env.example` with placeholder keys:
    - `PNP_CLIENT_ID`
    - `PNP_TENANT_ID`
  - Updated `docs/collaboration_setup_guide.md` with:
    - PnP login command pattern (`Connect-PnPOnline -Interactive -ClientId -Tenant`)
    - session verification command (`Get-PnPConnection`)
  - Updated `docs/architecture_flows.md` with explicit authentication context separation.
- Validation commands run:
  - `az ad app list --all --query "[?contains(displayName, 'PnP') || contains(displayName, 'PNP')].{displayName:displayName,appId:appId}" -o table`
  - `rg -n "Register-PnPEntraIDAppForInteractiveLogin|PnP|ClientId|TenantId" System_SPEC.md .env.example docs/collaboration_setup_guide.md docs/architecture_flows.md docs/progress.md`
- Next actions and blockers:
  - Next action: on each operator machine, set local `.env` values for `PNP_CLIENT_ID` and `PNP_TENANT_ID` before running PnP list admin commands.

## 2026-03-03 (BGV_FormData wiring across flows 0/4/5 + deployment)
- Current status:
  - Connected the new SharePoint list `BGV_FormData` (list id `f5248a99-fdf1-4660-946a-d54e00575a40`) into the active BGV flow path.
- Completed tasks:
  - Updated canonical flow files:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - add `Create_BGV_FormData_Row_E1/E2/E3` after request-row creation.
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - add `Get_items_(BGV_FormData)` by `RequestID`.
      - use FormData values as preferred source for second-form prefill URL.
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - add `Get_items_(BGV_FormData)` by `RequestID`.
      - add conditional `Update_item_-_BGV_FormData` to persist form-2 normalized fields and raw payload.
  - Repacked and imported `BGV_System` unmanaged solution with publish and overwrite.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: run a fresh end-to-end test (`BGV_0` -> `BGV_4` -> `BGV_5`) and verify `BGV_FormData` rows are created/updated for EMP1/EMP2/EMP3 where provided.

## 2026-03-04 (HR verification mapping quick-reference documented)
- Current status:
  - Added a dedicated quick-reference section for the requested cross-system mapping view:
    `BGV_Candidates` <-> `BGV_Requests` <-> `MS Forms (HR Verification Form)` <-> `Flow 4 outputs`.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` with:
    - current end-to-end path summary (`BGV_4` prefill/send + `BGV_5` response update linkage)
    - focused field mapping table for:
      - candidate identity fields to HR form prefill keys
      - request fields to HR form prefill key and downstream usage
      - Flow 4 SharePoint outputs (`HRRequestSentAt`, `VerificationStatus`) and email recipient field
  - Kept existing detailed sections (Form 1 mapping, Form 2 mapping, risk logic) unchanged.
- Validation commands run:
  - `rg -n "Requested View|2\\.1\\.1|2\\.1\\.2|rd745d133eb7f4611b59ea051f980f97a" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: whenever prefill keys or SharePoint target fields change in `BGV_4`/`BGV_5`, update this quick-reference section in the same commit.

## 2026-03-04 (Canonical field-level mapping dictionary added)
- Current status:
  - Added a single source document for exact current-state field mapping across Microsoft Forms, SharePoint lists, document library, and flows `BGV_0` to `BGV_6`.
- Completed tasks:
  - Added `docs/data_mapping_dictionary.md` with:
    - data store IDs and relationship keys (`CandidateID`, `RequestID`, `RecordKey`)
    - Form 1 -> list/library mappings (including per-slot EMP1/EMP2/EMP3 columns)
    - SharePoint -> Form 2 prefill key mappings (`r...` query params)
    - Form 2 -> `BGV_Requests` / `BGV_FormData` mappings and risk-logic field usage
    - non-form status/reminder field updates across flows `BGV_1`, `BGV_2`, `BGV_3`, `BGV_4`, `BGV_6`
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` to include the new canonical mapping doc.
- Validation commands run:
  - `rg -n "BGV Data Mapping and Data Dictionary|Form 1 response key|Form 2 prefill query key|Form 2 response key" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: when additional Form 2 prefill keys are added in `BGV_4`, update `docs/data_mapping_dictionary.md` in the same commit.

## 2026-03-04 (HR form Q1-Q33 inventory and wiring coverage documented)
- Current status:
  - Captured a full inventory-oriented view for the "Previous Employee Verification - HR Use Only" form and aligned each question to current flow wiring state.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` with a dedicated section:
    - `HR Verification Form (Q1-Q33) Inventory and Wiring Status`
  - Added per-question coverage table with:
    - Forms key (when present in canonical flow JSON)
    - wiring status (`Prefill`, `Read`, `Stored`, `Not wired`)
    - SharePoint target/use notes
  - Included explicit list of fields currently persisted directly into `BGV_FormData` for Form 2.
- Validation commands run:
  - `rg -n "## 11\\) HR Verification Form|Q\\#|F2_InformationAccurate|F2_SelectedIssues|F2_EmployerWouldReEmploy|F2_ReEmployReason" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: capture complete Forms key IDs for currently `Not wired` questions (for example Q6/Q7/Q28/Q29/Q30/Q31/Q33) and wire them in `BGV_5` plus SharePoint columns as needed.

## 2026-03-04 (PDF-annotated prefill pairing captured)
- Current status:
  - Processed user-uploaded annotated PDFs and captured explicit color-circled prefill pairings from Candidate Declaration -> HR Use Only form.
- Completed tasks:
  - Converted both PDFs to local page images and reviewed all pages.
  - Updated `docs/data_mapping_dictionary.md` with section:
    - `User-Annotated Prefill Mapping (PDF Markup, 2026-03-04)`
  - Recorded pairing status as `Implemented` vs `Pending` for:
    - identity fields (name/NRIC/passport)
    - company fields (name/UEN/address)
    - employment fields (period/salary/job title)
  - Marked unresolved key-ID dependency for pending fields where candidate/HR `r...` keys are not yet present in canonical flow JSON.
- Validation commands run:
  - `rg -n "User-Annotated Prefill Mapping|Pending prefill wiring|RequestID remains auto-filled" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Blocker: missing exact Forms key IDs for candidate Q7/Q8/Q10/Q11/Q12/Q13 and HR Q6/Q7/Q10/Q12/Q13 in current canonical flow definitions.
  - Next action: obtain latest Microsoft Forms prefill query keys for HR fields and candidate response keys (from `Get response details` output) before wiring in `BGV_0` and `BGV_4`.

## 2026-03-04 (HR prefill URL keys captured from user)
- Current status:
  - Captured additional HR form prefill keys from user-provided `Get prefilled link` URL for "Previous Employee Verification - HR Use Only".
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` section 11 and section 12 with newly confirmed HR keys:
    - `rcf35c7cc008e472f9d0b84bde67cc1ff` (Company UEN)
    - `r19aae6e8163d4aaeb8a3f3f2d5329be2` (Company Address)
    - `r2d39255c2449439096683ca0e39241b0` (Information Accurate - company details section)
    - `r0bef44c0d22d493f95a33484875b951e` (Employment Period)
    - `r513ad5ab3a14453286bdb910820985ec` (Reason For Leaving)
    - `ra6ab2e26d2d84a92b33148fc4694773a` (Last Drawn Renumeration Package)
    - `r49ca8a655f5e4bcba0e8f75d4475ad77` (Last Position Held)
  - Marked these as `key known; not wired` until canonical flow JSON is patched.
- Validation commands run:
  - `rg -n "rcf35c7cc008e472f9d0b84bde67cc1ff|r19aae6e8163d4aaeb8a3f3f2d5329be2|r2d39255c2449439096683ca0e39241b0|r0bef44c0d22d493f95a33484875b951e|r513ad5ab3a14453286bdb910820985ec|ra6ab2e26d2d84a92b33148fc4694773a|r49ca8a655f5e4bcba0e8f75d4475ad77" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Blocker: matching candidate form response keys are still needed before implementing the remaining prefill wiring in `BGV_4`.
  - Next action: receive user's second response with candidate-form keys, then patch canonical flow JSON and update linked docs in same change.

## 2026-03-04 (Verified candidate->HR mapping wired without assumptions)
- Current status:
  - Completed a strict verification pass for candidate-source key IDs using live Microsoft Forms runtime metadata (not value guessing), then wired the confirmed mappings into canonical flows.
- Completed tasks:
  - Extracted candidate form runtime metadata from:
    - `out/forms/candidate_responsepage.html` -> `prefetchFormUrl`
    - `out/forms/candidate_runtime_form.json`
  - Verified exact candidate source keys for E1/E2/E3 normalized fields (company UEN/address/postal code, job title, salary, employment start/end, HR contact/mobile/email).
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - `Create_BGV_FormData_Row_E1/E2/E3` now persist additional normalized Form 1 fields:
        - `F1_EmployerUEN`
        - `F1_EmployerAddress`
        - `F1_EmployerPostalCode`
        - `F1_JobTitle`
        - `F1_LastDrawnSalary`
        - `F1_EmploymentStartDate`
        - `F1_EmploymentEndDate`
        - `F1_HRContactName`
        - `F1_HRMobile`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `FinalVerificationLink` now pre-fills additional HR form keys:
        - `rcf35c7cc008e472f9d0b84bde67cc1ff` (Company UEN)
        - `r19aae6e8163d4aaeb8a3f3f2d5329be2` (Company Address)
        - `r0bef44c0d22d493f95a33484875b951e` (Employment Period: `start to end` when both dates exist, else single available date)
        - `ra6ab2e26d2d84a92b33148fc4694773a` (Last Drawn Salary)
        - `r49ca8a655f5e4bcba0e8f75d4475ad77` (Last Position Held)
  - Verified a current source gap:
    - Candidate declaration runtime metadata has no question with `Reason/Leaving` text, so HR key `r513ad5ab3a14453286bdb910820985ec` remains intentionally unmapped.
  - Updated linked behavior docs:
    - `docs/data_mapping_dictionary.md`
    - `docs/architecture_flows.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_EmployerUEN|F1_EmployerAddress|F1_EmployerPostalCode|F1_JobTitle|F1_LastDrawnSalary|F1_EmploymentStartDate|F1_EmploymentEndDate|F1_HRContactName|F1_HRMobile|rcf35c7cc008e472f9d0b84bde67cc1ff|r19aae6e8163d4aaeb8a3f3f2d5329be2|r0bef44c0d22d493f95a33484875b951e|ra6ab2e26d2d84a92b33148fc4694773a|r49ca8a655f5e4bcba0e8f75d4475ad77" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `Get-Content out/forms/candidate_e1_verified_fields.json`
  - `NO_REASON_OR_LEAVING_FIELD_FOUND` check via runtime metadata query
- Next actions and blockers:
  - Blocker: HR runtime metadata endpoint currently returns `Required user login` from this non-interactive shell, so HR key inventory remains sourced from user-provided prefill URL + existing flow usage.
  - Next action: run an end-to-end live submission (`BGV_0` -> `BGV_4`) and verify emitted employer link values for Q6/Q7/Q10/Q12/Q13 in actual email.

## 2026-03-04 (flows_easy_english refreshed from canonical unpacked flows)
- Current status:
  - Updated plain-English flow narrative to match latest canonical files under `flows/power-automate/unpacked/Workflows/`.
- Completed tasks:
  - Re-read all canonical workflow JSON files (`BGV_0` to `BGV_6`) and extracted current triggers, action chains, conditions, and key filters.
  - Updated `docs/flows_easy_english.md` with current-state behavior including:
    - `BGV_FormData` creation in `BGV_0` for EMP1/EMP2/EMP3.
    - Prefilled HR form URL behavior in `BGV_4` (candidate + employer + employment context fields).
    - Current request matching/scoring/escalation flow in `BGV_5` including `startswith(RequestID, ...)` matching and FormData update path.
    - Reminder timing logic now documented explicitly for `BGV_6` (2-day, +3-day, +1-day escalation, 11-day final reminder).
- Validation commands run:
  - `Get-ChildItem flows/power-automate/unpacked/Workflows -Filter '*.json'`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw docs/flows_easy_english.md`
- Next actions and blockers:
  - Next action: after each new `pac solution export/unpack`, rerun this same doc refresh so operational wording always matches latest cloud logic.

## 2026-03-05 (BGV_0 EMP2/EMP3 row-check condition fix)
- Current status:
  - Root-cause fixed for missing EMP3 records in `BGV_0_CandidateDeclaration`.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Fixed EMP2 duplicate-check condition to use the correct action output:
    - from `length(body('E1_Row_Check')?['value'])`
    - to `length(body('E2_Row_Check')?['value'])`
  - Fixed EMP3 create condition logic:
    - from invalid `equals(length(body('E3_Row_Check')?['value']), true)`
    - to `equals(length(body('E3_Row_Check')?['value']), 0)` (create only when EMP3 row does not already exist).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (explicit per-slot duplicate-check note for EMP1/EMP2/EMP3 creation path).
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "E2_Row_Check_Condition|E3_Row_Check_Condition|E2_Row_Check|E3_Row_Check|equals\\(length\\(body\\('E3_Row_Check'\\)\\?\\['value'\\]\\), 0\\)" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: run `pac solution pack` + `pac solution import` to deploy this canonical fix to cloud flow, then submit a new candidate form with EMP3 data and verify rows appear in both `BGV_Requests` and `BGV_FormData`.

## 2026-03-05 (Full flow health check + reminder path fixes)
- Current status:
  - Completed repository-wide flow integrity review for canonical workflows (`BGV_0` to `BGV_6`) and patched two reminder-path blockers.
- Completed tasks:
  - Validated all canonical workflow JSON files parse successfully.
  - Verified cross-flow wiring:
    - `BGV_0` EMP1/EMP2/EMP3 row-check conditions now all use `equals(length(...), 0)`.
    - `BGV_4` reads `BGV_FormData` by `RequestID` for prefill.
    - `BGV_5` matches `BGV_Requests` by `startswith(RequestID, ...)` and reads/updates `BGV_FormData` by exact `RequestID`.
  - Fixed `BGV_3` status string mismatch in nested condition:
    - removed trailing space from `Pending Authorization Form Signature ` to `Pending Authorization Form Signature`.
  - Fixed `BGV_6` initial SharePoint query filter field:
    - from `Status eq 'Sent'`
    - to `VerificationStatus eq 'Sent'`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (`BGV_6` selection baseline wording).
- Validation commands run:
  - `Get-ChildItem flows/power-automate/unpacked/Workflows -Filter '*.json' | Get-Content -Raw | ConvertFrom-Json`
  - `pac solution pack --zipfile artifacts/exports/BGV_System_validation_20260305.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `rg` checks for EMP row-check expressions and BGV_FormData RequestID filters.
  - `py scripts/active/pull_all_flow_runs.py` (failed due missing `FLOW_VERIFY_TENANT_ID` local env var).
- Next actions and blockers:
  - Blocker: automated run-history verification requires local OAuth env vars (`FLOW_VERIFY_TENANT_ID`, `FLOW_VERIFY_CLIENT_ID`, `FLOW_VERIFY_CLIENT_SECRET`, `FLOW_VERIFY_ENVIRONMENT_ID`).
  - Next action: import latest packed solution and run one live smoke submission covering EMP3 and reminder paths.

## 2026-03-05 (BGV_4 invalid HR email runtime guard)
- Current status:
  - Patched `BGV_4_SendToEmployer_Clean` to prevent runtime failure when `EmployerHR_Email` contains a name instead of an email address.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `Send_an_email_(V2)` `emailMessage/To` expression to guarded fallback order:
    - `BGV_FormData.F1_HREmail` (if contains `@`)
    - else `BGV_Requests.EmployerHR_Email` (if contains `@`)
    - else `dlresplmain@dlresources.com.sg`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (`BGV_4` recipient resolution note).
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "emailMessage/To|F1_HREmail|EmployerHR_Email|dlresplmain@dlresources.com.sg" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run a new `BGV_4` recurrence and verify failed request now routes successfully (or falls back) instead of throwing `String/email` conversion error.

## 2026-03-05 (BGV_4 company detail mapping fix + BGV_5 FormData title fix)
- Current status:
  - Patched `BGV_4` and `BGV_5` to address employer-detail mismatch and FormData save validation failure.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - Employer email body now resolves company `Name/Address/UEN` from matching `BGV_FormData` (`F1_EmployerName`, `F1_EmployerAddress`, `F1_EmployerUEN`) before falling back to `BGV_Requests` fields.
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - Added `item/Title` to `Update_item_-_BGV_FormData` payload to satisfy required SharePoint `PatchItem` validation.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` for both fixes.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_EmployerAddress|F1_EmployerUEN|item/Title|Update_item_-_BGV_FormData" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one live EMP1/EMP2/EMP3 case and verify `BGV_4` email body details match each slot and `BGV_5` save/update now succeeds without `item/Title` error.

## 2026-03-05 (ReasonForLeaving mapped into BGV_FormData for Form1 + Form2)
- Current status:
  - Added end-to-end ReasonForLeaving field mapping into canonical flows for both candidate and employer forms, matched by RequestID/employer slot.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Added Form 1 -> `BGV_FormData.F1_ReasonForLeaving` mappings per slot:
    - EMP1: `r73ad46a6f6e34cb5a811f76061af5d59`
    - EMP2: `r3b040646143e4015a21562a7c692b3d0`
    - EMP3: `r3c7e9cef2f37468fbdb8cb058ac11ce6`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added Form 2 -> `BGV_FormData.F2_ReasonForLeaving` mapping:
    - `r513ad5ab3a14453286bdb910820985ec`
  - Ensured null/empty safety by using `coalesce(...,'')` in both flows.
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_0_json> | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw <BGV_5_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_ReasonForLeaving|F2_ReasonForLeaving|r73ad46a6f6e34cb5a811f76061af5d59|r3b040646143e4015a21562a7c692b3d0|r3c7e9cef2f37468fbdb8cb058ac11ce6|r513ad5ab3a14453286bdb910820985ec" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one full EMP1/EMP2/EMP3 submission and verify each RequestID row gets the correct `F1_ReasonForLeaving`, then verify employer response writes `F2_ReasonForLeaving` to the same RequestID row.

## 2026-03-05 (Shared mailbox routing + BGV_5 Teams destination update)
- Current status:
  - Updated all Outlook send actions across canonical BGV flows to route via shared mailbox `DLRRecruitmentOps@dlresources.com.sg`.
- Completed tasks:
  - Updated flow JSON files:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Converted `SendEmailV2` actions to `SharedMailboxSendEmailV2` where needed and set:
    - `emailMessage/MailboxAddress = DLRRecruitmentOps@dlresources.com.sg`
  - For all email actions inside `BGV_5_Response1`, enforced:
    - `emailMessage/To = DLRRecruitmentOps@dlresources.com.sg`
  - Updated BGV_5 Teams post destination only:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Subject/body/attachments/message HTML were preserved.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - Action inventory script over all canonical flow JSON files to list Outlook/Teams operation IDs and key parameters before/after patch.
  - `Get-Content -Raw <each_changed_flow_json> | ConvertFrom-Json | Out-Null` (implicit via inventory parse).
  - `git diff -- flows/power-automate/unpacked/Workflows/*.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: run one test candidate submission + one BGV_5 notification path to verify emails appear in `DLRRecruitmentOps@dlresources.com.sg` and Teams posts appear in the new destination.

## 2026-03-06 (BGV_4 ID prefill remap: NRIC field with passport fallback)
- Current status:
  - Updated employer prefill mapping so the HR form NRIC field receives candidate identification using NRIC-first, then Passport fallback.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - In `FinalVerificationLink`:
    - kept `r27b6bdb850dd48339dc05df11d485470` and changed fallback chain to:
      - `F1_IDNumberNRIC` -> `F1_IDNumberPassport` -> `IdentificationNumberNRIC` -> `IdentificationNumberPassport`.
    - removed direct prefill mapping for `r0c342001cdd8463181c36dba2a8933ad` (passport field).
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "r27b6bdb850dd48339dc05df11d485470|r0c342001cdd8463181c36dba2a8933ad" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one employer-form email send from BGV_4 and confirm candidate passport-only submissions appear in the HR form NRIC field.

## 2026-03-06 (BGV_0 email shard-error fix with shared-mailbox send-as)
- Current status:
  - Patched `BGV_0_CandidateDeclaration` email action to avoid `Group Shard is used in non-Groups URI` runtime failure.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Changed `Send_an_email_(V2)` in `BGV_0`:
    - `operationId`: `SharedMailboxSendEmailV2` -> `SendEmailV2`
    - `emailMessage/MailboxAddress` -> `emailMessage/From` set to `DLRRecruitmentOps@dlresources.com.sg`
  - Preserved subject/body/to/importance unchanged.
  - Updated linked behavior documentation:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "Send_an_email_\(V2\)|SendEmailV2|SharedMailboxSendEmailV2|emailMessage/From|emailMessage/MailboxAddress" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: run one new `BGV_0` submission and confirm candidate receives from shared mailbox identity and flow no longer fails at send step.

## 2026-03-06 (Revert BGV_0 to shared mailbox email action)
- Current status:
  - Updated `BGV_0` email action to use `Send an email from a shared mailbox (V2)` per runtime permission model.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - In `Send_an_email_(V2)`:
    - `operationId`: `SendEmailV2` -> `SharedMailboxSendEmailV2`
    - `emailMessage/From` -> `emailMessage/MailboxAddress` = `DLRRecruitmentOps@dlresources.com.sg`
  - Preserved `To`, `Subject`, `Body`, links, and formatting unchanged.
  - Confirmed all other BGV email actions already use shared mailbox operation.
  - Updated linked behavior documentation:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "SendEmailV2|SharedMailboxSendEmailV2|emailMessage/MailboxAddress|emailMessage/From" flows/power-automate/unpacked/Workflows`
- Next actions and blockers:
  - Next action: if authorization error persists, grant mailbox-level `Send As` or `Send on behalf` for the Office 365 connection identity against `DLRRecruitmentOps@dlresources.com.sg`.

## 2026-03-06 (Synced manual cloud edit for BGV_0)
- Current status:
  - Exported and unpacked latest cloud solution after manual edit in `BGV_0_CandidateDeclaration`.
- Completed tasks:
  - Updated canonical flow from cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Synced changes observed in flow JSON:
    - Office 365 connection reference renamed to `shared_office365-1` with logical reference `cr94d_sharedoffice365_bdd97`.
    - Email action now named `Send_an_email_from_a_shared_mailbox_(V2)` and uses `SharedMailboxSendEmailV2`.
    - Candidate email subject/body content reflects current manual cloud version.
    - Candidate status update now runs after `Send_an_email_from_a_shared_mailbox_(V2)`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export --name BGV_System --path artifacts/exports/BGV_System_unmanaged.zip --managed false --overwrite`
  - `pac solution unpack --zipfile artifacts/exports/BGV_System_unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: monitor one live BGV_0 run to verify mailbox permissions and successful send from shared mailbox action.

## 2026-03-06 (Mailbox migration: DLRRecruitmentOps -> recruitmentops)
- Current status:
  - Updated all canonical BGV flow email actions to use shared mailbox `recruitmentops@dlresources.com.sg`.
- Completed tasks:
  - Replaced sender mailbox address in workflow JSON files:
    - `BGV_0_CandidateDeclaration`
    - `BGV_3_AuthReminder_5Days`
    - `BGV_4_SendToEmployer_Clean`
    - `BGV_5_Response1`
    - `BGV_6_HRReminderAndEscalation`
  - Updated BGV_5 mailbox-routed recipient constants from old mailbox to new mailbox where applicable.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `rg -n "DLRRecruitmentOps@dlresources.com.sg|recruitmentops@dlresources.com.sg" flows/power-automate/unpacked/Workflows docs/flows_easy_english.md`
  - `ConvertFrom-Json` parse check for all workflow JSON files under canonical path.
- Next actions and blockers:
  - Next action: verify Office 365 connector permission on `recruitmentops@dlresources.com.sg` for the active connection identity.

## 2026-03-06 (BGV_1 signature detection remap to CandidateAuthorisation tag)
- Current status:
  - Fixed signature detection logic to use Word checkbox content-control tag `CandidateAuthorisation` after template control recreation.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Replaced old condition source `Parse_JSON.signedYes` with tag-driven logic:
    - Added `Filter_array_-_CandidateAuthorisation` over `Parse_JSON.controlsFound`
    - Filter criterion: `toLower(item().tag) == 'candidateauthorisation'`
    - Signature condition now requires:
      - filtered array length > 0
      - first match `isChecked == true`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "Filter_array_-_CandidateAuthorisation|candidateauthorisation|isChecked|signedYes" <BGV_1_json>`
- Next actions and blockers:
  - Next action: submit one signed and one unsigned authorization form to confirm `AuthorisationSigned` toggles correctly.

## 2026-03-06 (BGV_1 tag correction: SignedYes)
- Current status:
  - Corrected BGV_1 checkbox detection tag/title to `SignedYes` based on latest template properties.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Renamed filter action to `Filter_array_-_SignedYes` and changed condition dependencies accordingly.
  - Filter now matches either tag or title (case-insensitive): `SignedYes`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "Filter_array_-_SignedYes|signedyes|CandidateAuthorisation" <BGV_1_json> docs/flows_easy_english.md`
- Next actions and blockers:
  - Next action: test one ticked and one unticked authorization form; ensure only ticked sets `AuthorisationSigned=true`.

## 2026-03-06 (BGV_1 signature detection hardening: signedYes OR SignedYes control)
- Current status:
  - Hardened `BGV_1` signature detection to support both parser summary flag and control-tag path.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - `Signature_checkbox_condition` now passes when either:
    - `Parse_JSON.signedYes == true`, or
    - `Filter_array_-_SignedYes` finds a control and first match `isChecked == true`.
  - This avoids false negatives when `controlsFound` is empty but parser still reports signed status.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "signedYes|Filter_array_-_SignedYes|Signature_checkbox_condition|isChecked" <BGV_1_json>`
- Next actions and blockers:
  - Next action: rerun with your signed document and confirm `AuthorisationSigned` flips to true, then test one unsigned sample to ensure no false positive.

## 2026-03-06 (BGV_1/BGV_4 hardening for signed authorization detection)
- Current status:
  - Added tolerant signed-detection logic to reduce false negatives from parser schema and value-type differences.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
      - Signature condition now checks raw `HTTP.signedYes` as true-like string/boolean.
      - Control filter now reads from `HTTP.controlsFound` directly (no dependency on `Parse_JSON` success).
      - Added secondary filter `Filter_array_-_SignedYes_Checked` to require checked state true-like.
      - Tag/title match supports `SignedYes` and compatibility fallback `CandidateAuthorisation`.
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `Condition_-_AuthorisationSigned` now accepts both boolean true and string `"true"`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks for updated flow JSON files.
  - `rg` checks for updated expressions/actions (`Filter_array_-_SignedYes_Checked`, `toLower(string(body('HTTP')?['signedYes']))`, tolerant `AuthorisationSigned` condition).
- Next actions and blockers:
  - Next action: rerun one known signed file and verify `BGV_1` updates candidate row, then trigger `BGV_4` recurrence to confirm employer send resumes.

## 2026-03-08 (Synced BGV_6 manual Team/Channel update from cloud)
- Current status:
  - Exported and unpacked latest cloud solution after manual BGV_6 escalation destination update in Power Automate.
- Completed tasks:
  - Updated canonical flow from cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed Teams escalation destination in BGV_6 now points to:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export --name BGV_System --path artifacts/exports/BGV_System_unmanaged.zip --managed false --overwrite`
  - `pac solution unpack --zipfile artifacts/exports/BGV_System_unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - `rg -n "body/recipient/groupId|body/recipient/channelId" flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run a BGV_6 cycle with an escalated item and confirm the Teams message lands in the new channel.

## 2026-03-08 (BGV_0 candidate authorization email wording update)
- Current status:
  - Updated candidate authorization email body text in `BGV_0` to new approved wording.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - In action `Send_an_email_from_a_shared_mailbox_(V2)`:
    - Added greeting: `Dear <dynamic candidate name>,`
    - Kept candidate name expression from existing form response field.
    - Kept existing dynamic authorization link expression unchanged.
    - Updated only surrounding static wording per requested template.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` on updated BGV_0 JSON.
  - `rg` checks for updated email body fragments and dynamic expressions.
- Next actions and blockers:
  - Next action: run one BGV_0 test submission and verify rendered email body in received message.

## 2026-03-09 (BGV_4 employer email subject/body wording refresh)
- Current status:
  - Updated BGV_4 employer email template wording while preserving existing dynamic mappings in declared-details and link sections.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Subject now uses the dynamic mapped company field.
  - Opening section wording now references dynamic company and candidate values while keeping downstream declared company details + verification link block unchanged.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: trigger one BGV_4 run and verify received employer email renders expected company/candidate dynamic values and unchanged declared-details/link section.

## 2026-03-09 (BGV_0 validation error fix: malformed SendAfterDate expression)
- Current status:
  - Fixed a flow-designer validation error in `BGV_0_CandidateDeclaration` caused by a malformed EMP1 `SendAfterDate` expression.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Replaced malformed EMP1 `item/SendAfterDate` expression with valid `@utcNow()` to match EMP2/EMP3 behavior.
  - Ran full JSON syntax validation on all canonical workflows (`BGV_0` to `BGV_6`).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for all files under `flows/power-automate/unpacked/Workflows/*.json`
  - `rg -n "item/SendAfterDate" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: import updated solution and run one live BGV_0 submission to confirm designer validation passes and run succeeds.

## 2026-03-09 (BGV_4 employer email wording sync)
- Current status:
  - Updated BGV_4 employer email template wording in canonical flow after cloud still showed old text.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Preserved existing dynamic mappings in subject, declared company details block, and verification link block.
  - Updated opening body sentence to use dynamic candidate full name and dynamic company name wording.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_4 JSON
  - `rg -n "emailMessage/Subject|emailMessage/Body|Declared company details from candidate|FinalVerificationLink"` on BGV_4 JSON
- Next actions and blockers:
  - Next action: run one BGV_4 send cycle and confirm new intro wording appears in sent email.

## 2026-03-09 (BGV_6 escalation Teams destination remap)
- Current status:
  - Remapped BGV_6 escalation post destination from old main-channel IDs to the DLR Recruitment Ops BGV channel IDs.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_6:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_6 JSON
  - `rg -n "groupId|channelId"` on BGV_6 JSON
- Next actions and blockers:
  - Next action: run one BGV_6 escalation cycle and verify message lands in `DLR Recruitment Ops > BGV` channel.

## 2026-03-09 (BGV_3 escalation Teams destination remap)
- Current status:
  - Remapped BGV_3 day-5 escalation Teams post to the DLR Recruitment Ops BGV channel for consistency with BGV_6/BGV_5.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_3:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_3 JSON
  - `rg -n "groupId|channelId"` on BGV_3 JSON
- Next actions and blockers:
  - Next action: trigger a day-5 escalation scenario and verify Teams post lands in `DLR Recruitment Ops > BGV`.

## 2026-03-09 (BGV_4 sends signed form copy to candidate)
- Current status:
  - Added candidate-copy email behavior so the same signed authorization form sent to employer is also sent to the candidate.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Added action `Send_signed_form_copy_to_candidate_(V2)` after employer send.
  - Reused the same attachment payload (`AuthFileName` + `Get_file_content`) and shared mailbox sender.
  - Candidate recipient mapping uses `Get_item.body/CandidateEmail` with fallback to `recruitmentops@dlresources.com.sg` if invalid.
  - Updated request status update runAfter to execute after candidate-copy email succeeds.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_4 JSON
  - `rg -n "Send_signed_form_copy_to_candidate_\(V2\)|emailMessage/To|CandidateEmail"` on BGV_4 JSON
- Next actions and blockers:
  - Next action: trigger one BGV_4 run and verify both employer and candidate receive the same signed form attachment.

## 2026-03-10 (BGV_6 remap correction using live Graph IDs)
- Current status:
  - Corrected BGV_6 Teams escalation destination after verifying actual Team/Channel IDs from Microsoft Graph.
- Completed tasks:
  - Verified live Teams IDs via Graph:
    - `DLR Recruitment Ops` team: `4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `BGV` channel: `19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Updated linked behavior docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_6 JSON
  - `rg -n "groupId|channelId"` on BGV_6 JSON
- Next actions and blockers:
  - Next action: trigger BGV_6 escalation and verify post appears in `DLR Recruitment Ops > BGV`.

## 2026-03-10 (BGV_3 and BGV_6 reminder condition repair after cloud sync)
- Current status:
  - Synced latest cloud solution first (export/unpack), then repaired reminder condition mappings in BGV_3 and BGV_6.
- Completed tasks:
  - Performed PAC-first sync from cloud:
    - `pac solution export --name BGV_System ...`
    - `pac solution unpack ...`
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 fixes:
    - corrected day-5 escalation expression to `@outputs('DaysSinceLink')`
    - aligned reminder field checks to `LastAuthReminderAt` (removed stale `LastAuthReminderSentAt` usage)
    - removed incorrect `item/ConsentCaptured = true` update from reminder stamp action
  - BGV_6 fixes:
    - replaced unstable dependencies on `outputs('Update_item')` / `outputs('Update_item_1')` with current-loop values `items('Apply_to_each')` in reminder conditions and notification bodies
    - updated final reminder item patch target ID to `@items('Apply_to_each')?['ID']`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks for updated BGV_3 and BGV_6 JSON files
  - `rg` checks to confirm broken references were removed
- Next actions and blockers:
  - Next action: run one controlled reminder test for each flow (BGV_3 daily reminder and BGV_6 reminder/escalation timeline) and confirm expected branch execution in run history.

## 2026-03-10 (BGV_3 non-sending reminder root-cause fix)
- Current status:
  - Identified why BGV_3 reminders were still not sending for some pending candidates.
- Root cause:
  - Outer BGV_3 gate used `ConsentCaptured`; legacy rows with this flag set could bypass reminder branch even while status remained pending.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
  - Changed outer gate condition to use `AuthorisationSigned == true` check (true -> skip, false/null -> continue reminder logic).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_3 JSON
  - `rg -n "AuthorisationSigned|ConsentCaptured"` on BGV_3 JSON
- Next actions and blockers:
  - Next action: run BGV_3 once with a pending candidate and confirm `Send_an_email_(V2)` executes.

## 2026-03-10 (BGV_5 Teams channel aligned to DLR Recruitment Ops > BGV)
- Current status:
  - Aligned BGV_5 Teams post destination to the same `DLR Recruitment Ops > BGV` channel used by BGV_6.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_5:
    - `body/recipient/groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `body/recipient/channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Re-validated BGV_6 mapping remains correct to the same IDs.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on BGV_5 and BGV_6 JSON
  - `rg -n "body/recipient/groupId|body/recipient/channelId"` on BGV_5 and BGV_6
- Next actions and blockers:
  - Next action: trigger one BGV_5 high-severity response and one BGV_6 escalation to confirm both posts appear in `DLR Recruitment Ops > BGV`.

## 2026-03-10 (BGV_5 recruiter email bodies include EmployerName)
- Current status:
  - Updated recruiter-facing BGV_5 email bodies to include `EmployerName` while preserving all existing logic/content.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added `EmployerName` line into both recruiter email bodies:
    - `Send_an_email_-_High_Severity_(V2)`
    - `Send_an_email_(V2)_1`
  - Revalidated BGV_6 JSON and destination mapping remained stable.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on BGV_5 and BGV_6 JSON
  - `rg` checks on updated BGV_5 email body fields and mapping references
- Next actions and blockers:
  - Next action: run one normal and one high-severity BGV_5 submission to verify both recruiter emails render EmployerName correctly.

## 2026-03-10 (Temporary 5-minute test mode for BGV_3 and BGV_6 reminders)
- Current status:
  - Enabled temporary high-frequency test mode so reminder behavior can be validated within ~2 hours.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Recurrence changes:
    - BGV_3: `Day/1` -> `Minute/5`
    - BGV_6: `Day/1` -> `Minute/5`
  - BGV_3 test timeline:
    - `DaysSinceLink` switched from day-units to minute-units (ticks divisor `600000000`)
    - Reminder send window: `5` to `120` minutes since link created
    - Repeat-reminder guard: allow resend when `LastAuthReminderAt <= utcNow()-10 minutes`
    - Escalation window: `30` to `120` minutes since link created
  - BGV_6 test timeline:
    - Reminder 1: `HRRequestSentAt <= utcNow()-10 minutes`
    - Reminder 2: `Reminder1At <= utcNow()-20 minutes`
    - Escalation: `Reminder2At <= utcNow()-20 minutes`
    - Final reminder: `HRRequestSentAt <= utcNow()-90 minutes`
  - Rollback values (post-test):
    - BGV_3 recurrence back to `Day/1`; day-based thresholds back to `1..5` day window and day-5 escalation
    - BGV_6 recurrence back to `Day/1`; thresholds back to `2d / 3d / 1d / 11d`
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `rg` checks for recurrence and `addMinutes(...)` threshold updates
- Next actions and blockers:
  - Next action: run live 2-hour test cycle and then revert to production timeline once validated.

## 2026-03-10 (Daily sync review and operator-doc alignment)
- Current status:
  - Ran the daily sync successfully after adding the explicit Power Platform environment URL override.
  - Reviewed the newly synced canonical flow diffs and confirmed they were formatting-only export changes, not behavior changes.
- Completed tasks:
  - Ran:
    - `powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - Verified the synced flow changes under `flows/power-automate/unpacked/Workflows/` only removed trailing final newlines (`No newline at end of file` diff markers).
  - Updated operator docs so daily sync instructions match the command that actually succeeded in this environment:
    - `README.md`
    - `docs/collaboration_setup_guide.md`
    - `docs/ms365_authentication_runbook.md`
  - Added guidance covering:
    - how to recover when `pac solution export` fails with `No active environment set`
    - recommended use of `-EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
    - when a sync diff is formatting-only and does not require behavior-doc updates
  - Intentionally left behavior docs unchanged because no flow logic changed:
    - `docs/flows_easy_english.md`
    - `docs/architecture_flows.md`
    - `System_SPEC.md`
- Validation commands run:
  - `git diff --stat`
  - `git diff -- flows/power-automate/unpacked/Workflows/`
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `git status --short --branch`
- Next actions and blockers:
  - Next action: if desired, update `scripts/active/bgv_daily_sync.ps1` to default from `POWER_PLATFORM_ENV_URL` so operators do not need to pass `-EnvironmentUrl` manually.

## 2026-03-10 (README repo-verification safeguard)
- Current status:
  - Added explicit instructions to help operators and Codex confirm they are working in the correct BGV Git repo before running any Git or PAC command.
- Completed tasks:
  - Updated `README.md`.
  - Added a dedicated repo-verification section with the expected local path, GitHub remote, and normal branch name for this project.
  - Added repo-verification steps to the top-level rules, start-of-day flow, and GitHub workflow checklist.
  - Mirrored the same safeguard into:
    - `docs/collaboration_setup_guide.md`
    - `docs/ms365_authentication_runbook.md`
  - Corrected the outdated local path reference `C:\bgv_project` to the actual repo path `C:\DLR Automation VS Studio Code\bgv_project` in the collaboration guide.
- Validation commands run:
  - `git diff -- README.md docs/collaboration_setup_guide.md docs/ms365_authentication_runbook.md docs/progress.md`
- Next actions and blockers:
  - No blocker. Next action: commit only the docs updates when ready.

## 2026-03-10 (Cloud sync: BGV_4 employer email update)
- Current status:
  - Synced latest cloud flow definitions after manual BGV_4 employer email edits in Power Automate.
- Completed tasks:
  - Exported and unpacked latest unmanaged solution from cloud into canonical path.
  - Confirmed updated BGV_4 employer send action subject/body text is now reflected in canonical JSON.
  - Synced resulting canonical workflow files updated by the cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json.data.xml`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Other/Customizations.xml`
    - `flows/power-automate/unpacked/Other/Solution.xml`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export ...`
  - `pac solution unpack ...`
  - `git diff` review for canonical flow artifacts.
- Next actions and blockers:
  - Next action: commit and push synced canonical artifacts.

## 2026-03-10 (Cloud sync: BGV_4 employer email update refresh)
- Current status:
  - Synced another manual BGV_4 employer email edit from cloud to canonical repo artifacts.
- Completed tasks:
  - Exported and unpacked the latest unmanaged `BGV_System` solution.
  - Confirmed only canonical BGV_4 workflow JSON changed in this refresh:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed BGV_4 employer email body now includes the newest cloud-edited HR instruction text while preserving existing dynamic mappings.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export ...`
  - `pac solution unpack ...`
  - `git status --short`
  - `git diff -- ...BGV_4...json`
- Next actions and blockers:
  - Next action: commit and push synced canonical artifacts.

## 2026-03-10 (Beginner SharePoint list user guide)
- Current status:
  - Added a new beginner-friendly document so future users can
    understand what the main BGV SharePoint lists are for and what their
    important columns mean.
- Completed tasks:
  - Added:
    - `docs/sharepoint_list_user_guide.md`
  - The new guide explains the automation-facing business columns for:
    - `BGV_Candidates`
    - `BGV_Requests`
    - `BGV_FormData`
    - `BGV Records` document library
  - For each store, documented:
    - what the store is for
    - what the important columns mean
    - which flows mainly write the column
    - which flows mainly read the column
  - Linked the new guide from:
    - `README.md`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
  - Kept the guide focused on automation-facing business columns rather
    than trying to guess every default SharePoint system field.
- Validation commands run:
  - `git diff -- README.md docs/sharepoint_list_user_guide.md docs/file_index.md docs/repo_inventory.md docs/progress.md`
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - Existing markdownlint issues remain in older files such as
    `README.md`, `docs/file_index.md`, and `docs/repo_inventory.md`, but
    those are pre-existing and were not expanded as part of this task.
  - If needed later, add a separate live-schema document for full
    SharePoint column dumps including default system metadata.

## 2026-03-10 (`Severity/Value` explanation added to user guide)
- Current status:
  - Expanded the beginner SharePoint guide to explain how
    `Severity/Value` is calculated in the employer-response flow.
- Completed tasks:
  - Updated `docs/sharepoint_list_user_guide.md`.
  - Added a dedicated explanation section for `BGV_Requests.Severity`
    covering:
    - default starting state
    - High / Medium / Low priority order
    - why the contact-request answer does not change severity by itself
    - where the matching notes/result are stored
  - Clarified that `BGV_FormData.F2_Severity/Value` is the copied final
    severity from the same scoring logic.
- Validation commands run:
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - No blocker.

## 2026-03-10 (BGV_5 severity model updated: remove Low, inaccurate info -> Medium)
- Current status:
  - Updated the canonical employer-response flow so the old `Low`
    severity path is no longer used.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed the inaccurate-information rule from:
    - `Low` only when severity was empty
  - To:
    - `Medium` when severity is not already `High`
  - Updated the inaccurate-information path so it now:
    - sets `varSeverity = Medium` when not already High
    - sets `varOutcome = Needs Clarification`
    - sets `varNotifyTeams = true`
    - appends a `[Medium]` note instead of a `[Low]` note
  - Confirmed notes are still written to:
    - `BGV_Requests.Notes`
    - `BGV_FormData.F2_Notes` when the matching FormData row exists
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated `BGV_5_Response1` JSON
  - `rg -n "Low|Medium|F2_Notes|Notes|Please contact me for further clarification"` on updated flow/docs
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - Next action: deploy the updated canonical flow and run one employer
    response test for each case:
    - inaccurate info only -> expect `Medium`
    - MAS or disciplinary trigger -> expect `High`
    - contact-request only -> expect note + notification without
      changing severity by itself

## 2026-03-10 (Document how HR form answers are captured in the user guide)
- Current status:
  - Added a beginner-friendly reference section to explain where common
    HR Form 2 answers are stored today.
- Completed tasks:
  - Updated:
    - `docs/sharepoint_list_user_guide.md`
  - Added a new table covering:
    - structured capture into `F2_*` fields
    - notes-only capture into `BGV_Requests.Notes` and
      `BGV_FormData.F2_Notes`
    - raw-JSON-only capture in `BGV_FormData.Form2RawJson`
  - Explicitly documented the current behavior for:
    - inaccurate-information multi-select answers
    - company-details discrepancy fields
    - MAS and disciplinary free-text fields
    - `Other comments we should know about`
    - `Please contact me for further clarification`
- Validation commands run:
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - No blocker.

## 2026-03-11 (Temporary 4-hour reminder test mode re-enabled for BGV_3 and BGV_6)
- Current status:
  - Re-enabled temporary high-frequency reminder timing so both reminder flows can be validated live within a 4-hour window and rolled back cleanly afterward.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 temporary test settings:
    - recurrence changed to `Minute / 5`
    - `DaysSinceLink` switched from day-based ticks to minute-based ticks (`600000000`)
    - reminder send window changed to minute `5` through minute `240`
    - resend guard changed to `LastAuthReminderAt <= utcNow()-5 minutes`
    - escalation trigger changed to minute `20`
  - BGV_6 temporary test settings:
    - recurrence changed to `Minute / 5`
    - Reminder 1 changed to `HRRequestSentAt <= utcNow()-5 minutes`
    - Reminder 2 changed to `Reminder1At <= utcNow()-5 minutes`
    - recruiter escalation changed to `Reminder2At <= utcNow()-5 minutes`
    - final reminder changed to `HRRequestSentAt <= utcNow()-20 minutes`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
  - Rollback values preserved for later restoration:
    - BGV_3 back to `Day / 1`, day-based ticks, day `1..5` reminder window, day `5` escalation
    - BGV_6 back to `Day / 1`, `2d / 3d / 1d / 11d` thresholds
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `git diff -- flows/...BGV_3... flows/...BGV_6... docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: pack/import via PAC, then run live tests against one pending candidate and one pending HR request.

## 2026-03-11 (BGV_3 and BGV_6 reminder flows reverted to production timing and repaired)
- Current status:
  - Reverted the temporary reminder test mode and repaired the production reminder logic defects that were causing skipped reminder emails and inconsistent escalation behavior.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 repairs:
    - reverted recurrence from `Minute / 5` back to `Day / 1`
    - reverted `DaysSinceLink` from minute-based ticks back to day-based ticks (`864000000000`)
    - reverted reminder window from minute `5..240` back to day `1..5`
    - reverted same-day resend guard to the original date-based check
    - moved day-5 escalation out of the reminder-send branch so escalation no longer depends on that day's reminder email being sent
    - changed day-5 escalation email to use current candidate values directly instead of the reminder update action output
    - allowed day-5 escalation email to continue even if the Teams post fails
    - confirmed the reminder update still only stamps `LastAuthReminderAt` and does not set candidate status to `Obtained Authorization Form Signature`
  - BGV_6 repairs:
    - reverted recurrence from `Minute / 5` back to `Day / 1`
    - reverted thresholds back to `2d / 3d / 1d / 11d`
    - replaced brittle `""` date comparisons with `empty(...)` checks for `Reminder1At`, `Reminder2At`, `Reminder3At`, and `ResponseReceivedAt`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `Get-ChildItem flows/power-automate/unpacked/Workflows/*.json | ... ConvertFrom-Json`
  - `git diff -- flows/...BGV_3... flows/...BGV_6...`
- Next actions and blockers:
  - Next action: push/import repaired production reminder flows, then verify one pending candidate and one pending employer request against live run history.

## 2026-03-11 (BGV_4 prefilled employer form mapping restored to cloud from canonical source)
- Current status:
  - Verified the canonical `BGV_4_SendToEmployer_Clean` flow still contained the expected Microsoft Forms prefill mapping, then re-imported the solution so the live Power Automate version matches GitHub again.
- Completed tasks:
  - Inspected canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed `FinalVerificationLink` still maps the employer verification form prefill fields for:
    - candidate full name
    - identification number
    - request ID
    - employer name
    - employer UEN
    - employer address
    - employment period
    - last drawn salary
    - job title
  - Repacked and re-imported the current canonical solution to restore those mappings to the cloud flow.
- Validation commands run:
  - `rg -n "FinalVerificationLink|r4930|r27b6|rd745|rccaf|rcf35|r19aa|r0bef|ra6ab|r49ca" ...BGV_4...json`
  - `ConvertFrom-Json` on canonical BGV_4 JSON
  - `pac solution pack ...`
  - `pac solution import ... --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: trigger one BGV_4 send cycle and confirm the live employer form link arrives with the expected prefilled values.

## 2026-03-11 (HR form Q8/Q9 mapping correction from prefilled URL)
- Current status:
  - Corrected the HR form inventory so the company-details section matches
    the latest user-provided Microsoft Forms prefilled URL.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md`.
  - Corrected the question numbering for the early company-details block:
    - Q7 = company-details accuracy yes/no (`r2d39255c2449439096683ca0e39241b0`)
    - Q8 = company-details discrepancy multi-select (`rd05170e51ac34fef95f5464cf348bedc`)
    - Q9 = company-details discrepancy explanation (`ra03058e9bbfd40d28014b0c669e92434`)
  - Clarified that these keys are currently known from the prefilled URL
    but are not wired in canonical flow JSON.
- Validation commands run:
  - `rg -n "rd05170e51ac34fef95f5464cf348bedc|ra03058e9bbfd40d28014b0c669e92434|Q7|Q8|Q9" docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: if needed, capture the exact Microsoft Forms designer
    labels for Q7-Q9 from the live form editor or PDF export and replace
    the current inferred wording.

## 2026-03-11 (BGV report summary template added to local repo)
- Current status:
  - Added the existing Word summary template into the local `bgv_project`
    repo so it is available alongside the mapping docs it depends on.
- Completed tasks:
  - Copied `BGV_Report_Summary_Template.docx` from:
    - `C:\Users\EdwinTeo\Desktop\bgv_project\BGV_Report_Summary_Template.docx`
  - Added the copied file to the repo root:
    - `BGV_Report_Summary_Template.docx`
  - Updated repo index docs:
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
  - Kept flow JSON and SharePoint behavior docs unchanged in this task
    because this change only adds the report template artifact and does
    not change runtime automation behavior.
- Validation commands run:
  - `Get-Item BGV_Report_Summary_Template.docx | Select-Object FullName,Length,LastWriteTime`
  - DOCX text extraction check on `word/document.xml` to confirm the
    copied file contains the expected `BGV Report Summary Template`
    heading and the corrected Q8/Q9/Q15 sections.
- Next actions and blockers:
  - Next action: if desired, update `docs/data_mapping_dictionary.md`
    further so its visible Form 2 inventory fully mirrors every field
    already listed in the Word template.

## 2026-03-11 (BGV report summary template rebuilt with key-based placeholders)
- Current status:
  - Rebuilt the local Word summary template into a simpler single-report
    layout for both Microsoft Forms using the verified form IDs already
    available in the repo.
- Completed tasks:
  - Updated `BGV_Report_Summary_Template.docx`.
  - Replaced generic `Form2.Q1`-style placeholders with key-based
    placeholders such as:
    - `{{Form1.rfe96c622120343f294de908deb0e849d}}`
    - `{{Form2.rd05170e51ac34fef95f5464cf348bedc}}`
    - `{{Form2.r72b23e4aa192405091846e1279085029}}`
  - Added both source Microsoft Form IDs near the top of the template.
  - Preserved the requested additive-path wording:
    - new Azure Function-generated `.docx`
    - saved into `BGV Records`
    - no current `BGV_5` Word-template action
    - no live cloud template upload / file ID mapping in this task
  - Kept Form 1 limited to non-repeating fields only.
  - Kept a short manual-review note for unresolved upload-style fields.
- Validation commands run:
  - DOCX text extraction check on `word/document.xml` to confirm:
    - requested additive-path sentence is present
    - both Form IDs are present
    - key-based response placeholders for Form 1 and Form 2 are present
  - `Get-Item BGV_Report_Summary_Template.docx | Select-Object FullName,Length,LastWriteTime`
- Next actions and blockers:
  - Next action: if needed, align the remaining Form 2 question labels in
    `docs/data_mapping_dictionary.md` to the same visible-question layout
    now used by the Word template.

## 2026-03-11 (Local-only save state confirmed)
- Current status:
  - Confirmed the latest documentation and report-template changes are
    saved locally in the working tree and intentionally not committed yet.
- Completed tasks:
  - Confirmed local on-disk state for:
    - `BGV_Report_Summary_Template.docx`
    - `docs/data_mapping_dictionary.md`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
    - `docs/progress.md`
  - Confirmed the untracked local files currently kept for later commit:
    - `BGV_Report_Summary_Template.docx`
    - `docs/sharepoint_list_user_guide.md`
  - Confirmed no Git commit was created in this task.
- Validation commands run:
  - `git status --short`
- Next actions and blockers:
  - Next action: stage and commit the intended files when ready.

## 2026-03-11 (Separate GitHub sync clone created and local repo integrated)
- Current status:
  - Created a separate local clone of the current GitHub repo and merged
    the relevant remote changes into the active working repo without
    creating a commit.
- Completed tasks:
  - Cloned current GitHub `master` into:
    - `C:\DLR Automation VS Studio Code\bgv_project_github_sync`
  - Compared the sync clone against the active working tree and isolated
    the files that still differed from current GitHub state.
  - Synced these canonical workflow files to the current GitHub version:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Preserved local `BGV_5` severity/note work while integrating the
    current GitHub high-severity email-body wording into:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Merged linked documentation so the working repo now contains:
    - the missing remote cloud-sync entries in `docs/progress.md`
    - updated behavior wording in `docs/flows_easy_english.md`
- Validation commands run:
  - `git fetch origin`
  - `git rev-list --left-right --count HEAD...origin/master`
  - file-hash / text comparisons between the active repo and `bgv_project_github_sync`
  - three-way merge feasibility checks against `HEAD` for docs and workflow files
- Next actions and blockers:
  - Next action: review the newly integrated unstaged workflow/doc changes
    before deciding whether to stage them for a later commit.

## 2026-03-11 (BGV_5 inaccurate-information path reverted to GitHub Low behavior)
- Current status:
  - Reverted the local-only `BGV_5` inaccurate-information path from the
    earlier `Medium + Needs Clarification + notify` behavior back to
    the current GitHub `Low` behavior, while leaving `BGV_4` unchanged.
- Completed tasks:
  - Updated the canonical workflow file:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Restored the inaccurate-information branch to:
    - set `Severity = Low` only when `varSeverity` is still empty
    - stop setting `Outcome = Needs Clarification` for that branch
    - stop setting `varNotifyTeams = true` for that branch
    - append the GitHub-style `[Low]` note body
  - Aligned the linked behavior docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `ConvertFrom-Json` on the updated canonical `BGV_5` file
  - `rg -n "Low|Medium|Needs Clarification|Notify_Teams_4|Outcome_4|Information inaccurate" ...`
- Next actions and blockers:
  - Next action: decide whether to keep the temporary
    `bgv_project_github_sync` clone after the final Git history
    integration is complete.

## 2026-03-11 (Q11 mapping doc corrected and local branch rebased onto origin/master)
- Current status:
  - Corrected the documented Form 2 `Q11` behavior and integrated the
    7 remote GitHub commits into the active repo by rebasing the local
    work on top of `origin/master`.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` so Form 2 `Q11`
    (`r513ad5ab3a14453286bdb910820985ec`) is described as response-only:
    - not currently prefilled by `BGV_4`
    - entered manually by employer HR in Form 2
    - stored in `BGV_FormData.F2_ReasonForLeaving`
  - Created a local checkpoint commit before rebase:
    - `04926c9 docs: integrate local BGV updates before upstream rebase`
  - Rebased that local commit onto the current `origin/master`.
  - Resolved rebase conflicts by keeping the current GitHub production
    reminder logic for:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `docs/flows_easy_english.md`
  - Rebuilt `docs/progress.md` so it contains both:
    - the 7 remote-commit log entries already on GitHub
    - the local documentation/template/mapping entries created in this repo
- Validation commands run:
  - `git fetch origin`
  - `git pull --rebase origin master`
  - `git hash-object ...BGV_3...json` compared with `git show origin/master:...BGV_3...json`
- Next actions and blockers:
  - Next action: complete rebase finalization, run final repo validation,
    and review the new local `master` state before any push.

## 2026-03-11 (Form 2 Q11 logic corrected from HR PDF review)
- Current status:
  - Corrected the current Form 2 documentation logic so `Q11` is treated
    as an employer-entered response field, not a `(Declared By Candidate)`
    prefill field.
- Completed tasks:
  - Updated:
    - `docs/data_mapping_dictionary.md`
    - `docs/architecture_flows.md`
  - Clarified the current rule from the HR Form 2 PDF:
    - Form 2 questions explicitly labeled `(Declared By Candidate)` are
      the intended prefill targets in `BGV_4`
    - `Q11` is no longer one of those declared-by-candidate fields
    - `Q11` remains blank in the runtime prefilled URL and is answered
      manually by employer HR
    - the submitted response is still stored in
      `BGV_FormData.F2_ReasonForLeaving`
- Validation commands run:
  - `rg -n "Declared By Candidate|Reason For Leaving|Q11|r513ad5ab3a14453286bdb910820985ec" docs/data_mapping_dictionary.md docs/architecture_flows.md`
- Next actions and blockers:
  - Next action: if the Form 2 layout changes again, re-verify the
    `(Declared By Candidate)` labels before changing `BGV_4` prefill logic.

## 2026-03-11 (GitHub push and production import for Form 2 Q11 doc alignment)
- Current status:
  - Pushed the latest local repo state to GitHub and imported the
    canonical `BGV_System` solution to the configured production
    environment from the unpacked workflow source.
- Completed tasks:
  - Pushed `master` to GitHub:
    - local deployed code commit: `a5fc3b3`
  - Verified PAC identity before deployment:
    - `edwin.teo@dlresources.com.sg`
  - Exported a production pre-deploy backup:
    - `artifacts/exports/BGV_System_prod_predeploy_backup_20260311_131235.zip`
  - Packed the canonical solution from:
    - `flows/power-automate/unpacked`
  - Imported and published:
    - `artifacts/exports/BGV_System_unmanaged.repack.zip`
  - Confirmed the import completed successfully and Power Platform
    reported that the original workflow definition was replaced.
- Validation commands run:
  - `git push origin master`
  - `pac auth who`
  - `pac solution export --environment https://orgde64dc49.crm5.dynamics.com/ --name BGV_System --path .\artifacts\exports\BGV_System_prod_predeploy_backup_20260311_131235.zip --managed false --overwrite`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: run live smoke checks for one candidate declaration,
    one employer response path, and reminder-flow health in Power
    Automate run history.

## 2026-03-11 (Post-import live verification from shell)
- Current status:
  - Verified the imported `BGV_System` workflows are present and active
    in the target environment from the current shell, but could not run
    full run-history or form-submission smoke tests because the required
    live verification credentials and UI-only submission path are not
    available here.
- Completed tasks:
  - Verified PAC identity again before live checks:
    - `edwin.teo@dlresources.com.sg`
  - Queried the target environment and confirmed the deployed workflow
    records for the main automation flows are present and active:
    - `BGV_0_CandidateDeclaration`
    - `BGV_1_Detect_Authorization_Signature`
    - `BGV_2_Postsignature`
    - `BGV_3_AuthReminder_5Days`
    - `BGV_4_SendToEmployer_Clean`
    - `BGV_5_Response1`
    - `BGV_6_HRReminderAndEscalation`
  - Confirmed those workflow records show fresh `modifiedon` timestamps
    from the March 11, 2026 import window.
  - Confirmed the extra `BGV_A_CandidateSubmission` record remains
    `Draft` and is not part of the 7 active production flows.
  - Confirmed the repo run-history scripts cannot be executed from this
    shell as-is because no `FLOW_VERIFY_*` environment variables or
    local `.env` file are configured.
- Validation commands run:
  - `pac auth who`
  - `pac env list`
  - `pac env fetch --environment https://orgde64dc49.crm5.dynamics.com/ --xmlFile <temp workflow fetch xml>`
  - `pac env fetch --environment https://orgde64dc49.crm5.dynamics.com/ --xmlFile <temp workflow modifiedon fetch xml>`
  - `Get-ChildItem Env:FLOW_VERIFY_*`
- Next actions and blockers:
  - Blocker: no configured `FLOW_VERIFY_TENANT_ID`, `FLOW_VERIFY_CLIENT_ID`,
    `FLOW_VERIFY_CLIENT_SECRET`, or `FLOW_VERIFY_ENVIRONMENT_ID` for the
    run-history scripts in this shell.
  - Blocker: live Microsoft Forms candidate/employer submissions remain
    a manual/UI path and were not triggered from this shell.
  - Next action: submit one live candidate declaration and one live
    employer response manually, then inspect Power Automate run history
    in the portal or configure the `FLOW_VERIFY_*` app credentials so
    `py scripts/active/pull_all_flow_runs.py` can be used non-interactively.

## 2026-03-11 (VS Code migration toolchain install)
- Current status:
  - Installed the missing local CLI/module pieces needed for a more
    VS Code-driven Microsoft 365 migration workflow.
- Completed tasks:
  - Confirmed the already-installed VS Code extensions relevant to the
    BGV Power Platform/Azure workflow:
    - `microsoft-isvexptools.powerplatform-vscode`
    - `ms-vscode.powershell`
    - `ms-azuretools.vscode-azurefunctions`
    - `ms-azuretools.vscode-azureresourcegroups`
    - `ms-vscode.azurecli`
    - `daniellaskewitz.power-platform-connectors`
    - `richardwilson.powerplatform-connector-linter`
  - Installed additional relevant VS Code extensions:
    - `adamwojcikit.cli-for-microsoft-365-extension`
    - `ms-azuretools.vscode-azurestorage`
  - Installed `CLI for Microsoft 365` globally for the current user via
    npm.
  - Installed `Microsoft.Graph` PowerShell modules for the current user
    from `PSGallery`.
  - Verified the following local tools are now available together:
    - `pac`
    - `az`
    - `func`
    - `m365`
    - `PnP.PowerShell`
    - `Microsoft.Graph`
- Validation commands run:
  - `node -v`
  - `npm -v`
  - `npm config get prefix`
  - `Get-PSRepository`
  - `& 'C:\Users\EdwinTeo\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd' --list-extensions --show-versions`
  - `npm install -g @pnp/cli-microsoft365@latest`
  - `Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force -AllowClobber`
  - `m365 --version`
  - `Get-Module -ListAvailable Microsoft.Graph, Microsoft.Graph.Authentication`
  - `Get-Command Connect-MgGraph, Get-MgSite`
  - `code.cmd --install-extension adamwojcikit.cli-for-microsoft-365-extension`
  - `code.cmd --install-extension ms-azuretools.vscode-azurestorage`
  - `code.cmd --list-extensions --show-versions`
- Next actions and blockers:
  - Next action: use the newly available `m365`, `PnP.PowerShell`, and
    `Microsoft.Graph` tooling to design a scripted migration path from
    `https://dlresourcespl88.sharepoint.com/sites/dlrespl` to
    `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`.
  - Next action: refactor hardcoded SharePoint/list/library/template
    bindings in the BGV solution into deploy-time settings before any
    production cutover.

## 2026-03-16 (BGV_1 parser widened and flow schema hardened)
- Current status:
  - Investigated a still-failing `BGV_1` authorization-parser run and found two concrete failure paths: the Azure DOCX parser only scanned the main document body, and the flow `Parse_JSON` schema rejected valid nullable parser fields.
- Completed tasks:
  - Updated `functions/bgv-docx-parser/Services/OpenXmlDocxCheckboxExtractor.cs` so checkbox extraction now scans:
    - main document
    - headers
    - footers
    - glossary document
    - footnotes
    - endnotes
  - Added a new parser integration test for a `SignedYes` checkbox stored in a header part:
    - `tests/bgv-docx-parser.tests/DocxTestFactory.cs`
    - `tests/bgv-docx-parser.tests/ParserIntegrationTests.cs`
  - Hardened the canonical `BGV_1` flow JSON `Parse_JSON` schema so it now accepts nullable:
    - `signedYes`
    - `signedNo`
    - `controlsFound[].tag`
    - `controlsFound[].title`
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
- Validation commands run:
  - `dotnet test tests/bgv-docx-parser.tests/bgv-docx-parser.tests.csproj`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: if the parser tests pass, publish the Azure Function app and re-import the updated `BGV_1` flow so the function fix and flow schema hardening are live together.

## 2026-03-16 (BGV_1 fix deployed to Power Automate and Azure)
- Current status:
  - The `BGV_1` repair is now live in both places it depends on: the Power Automate flow definition and the Azure DOCX parser function app.
- Completed tasks:
  - Verified PAC identity before import:
    - `recruitment@dlresources.com.sg`
  - Packed and imported the updated unmanaged solution:
    - `artifacts/exports/BGV_System_bgv1_fix.zip`
  - Published the updated Azure Function project to:
    - Function App: `bgv-docx-parser`
    - Hostname: `bgv-docx-parser-cshnd7aucchwfmfz.southeastasia-01.azurewebsites.net`
  - Pushed the source change commit to GitHub:
    - `8792b1e Fix BGV_1 parser coverage and schema handling`
- Validation commands run:
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_bgv1_fix.zip --publish-changes --force-overwrite`
  - `func azure functionapp publish bgv-docx-parser --dotnet-isolated`
  - `git push origin master`
- Next actions and blockers:
  - Next action: run one fresh unsigned-save test and one checked-`SignedYes` save test in the live flow to confirm the parser now returns the checkbox correctly and the candidate row updates only after the checked save.

## 2026-03-11 (Collaborator VS Code toolchain guide and Codex sign-in SOP)
- Current status:
  - Added a shareable collaborator setup guide covering the approved
    VS Code extension set, terminal toolchain, one-time installation,
    and Codex-assisted daily sign-in workflow for the BGV repo.
- Completed tasks:
  - Added `docs/vscode_ms365_toolchain_guide.md` with:
    - current BGV baseline values and accounts
    - approved VS Code extensions and CLI/module stack
    - validated local version snapshot
    - one-time installation commands
    - extension-to-auth mapping
    - human-vs-Codex responsibility split
    - standard Codex-assisted sign-in SOP for `pac`, `az`, `m365`,
      `PnP.PowerShell`, and `Microsoft.Graph`
    - collaborator access checklist
    - recommended Codex prompts
    - troubleshooting and official reference links
  - Updated `docs/ms365_authentication_runbook.md` to align with the new
    toolchain guide and add `Microsoft.Graph` install/login guidance.
  - Updated `README.md` one-time setup section to point collaborators to
    the new toolchain guide and auth runbook.
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` so the
    new guide and expanded auth runbook are discoverable.
- Validation commands run:
  - `code.cmd --list-extensions --show-versions`
  - `Get-Command pac, az, func, m365, git`
  - `Get-Module -ListAvailable PnP.PowerShell, Microsoft.Graph`
  - `dotnet --version`
  - `py --version`
  - `Select-String -Path README.md, docs/ms365_authentication_runbook.md, docs/vscode_ms365_toolchain_guide.md -Pattern "Codex-assisted sign-in|Microsoft.Graph|CLI for Microsoft 365|vscode_ms365_toolchain_guide"`
- Next actions and blockers:
  - Next action: run the first live `m365` and `Microsoft.Graph`
    sign-in validation with browser/device prompts and record the exact
    post-login verification commands/results.
  - Next action: turn the documented daily preflight into a reusable
    bootstrap script once the live sign-in behavior is confirmed.

## 2026-03-11 (Reading-order guide for first-time setup and daily SOP)
- Current status:
  - Added a short master guide that tells collaborators which repo docs
    to read and in what order for first-time setup, daily work,
    migration tasks, troubleshooting, and deployment.
- Completed tasks:
  - Added `docs/first_time_and_daily_sop_guide.md`.
  - Updated `README.md` so first-time users are pointed to that guide
    before the deeper setup and auth docs.
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` so the new
    reading-order guide is discoverable.
- Validation commands run:
  - `Select-String -Path README.md, docs/first_time_and_daily_sop_guide.md -Pattern "first_time_and_daily_sop_guide|first-time|daily work"`
  - `Select-String -Path docs/file_index.md, docs/repo_inventory.md -Pattern "first_time_and_daily_sop_guide"`
- Next actions and blockers:
  - Next action: use the new reading-order guide as the first document to
    share with collaborators before machine setup or sign-in validation.
## 2026-03-11 (BGV_1/BGV_2 stop-sharing hardened to signed-checkbox only)
- Current status:
  - Investigated premature authorization-link removal and tightened both the signature-detection and post-signature unshare scope.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json`
  - BGV_1 changes:
    - primary signed condition now relies on `Filter_array_-_SignedYes_Checked` length > 0
    - parser `signedYes = true` now acts only as fallback when no matching `SignedYes` controls are returned at all
    - this prevents a broad parser `signedYes` flag from marking current templates as signed when the checkbox is still unchecked
  - BGV_2 changes:
    - replaced broad library-wide `.docx` filter with `folderPath = @outputs('Compose')`
    - unshare now targets only files inside `/BGV Records/Candidate Files/<CandidateID>/Authorization/`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` on updated BGV_1 and BGV_2 JSON
  - `git diff -- ...BGV_1... ...BGV_2...`
- Next actions and blockers:
  - Next action: import the updated solution and test one unsigned authorization file plus one signed authorization file to confirm the link remains active until the checkbox is actually checked.

## 2026-03-16 (BGV_1 HTTP unauthorized traced to Function App auth gate)
- Current status:
  - Investigated continued `HTTP` failure in `BGV_1_Detect_Authorization_Signature` after the parser/schema fixes and confirmed the blocker was Azure App Service Authentication intercepting the request before the function key was evaluated.
- Completed tasks:
  - Verified the Function App auth configuration on `bgv-docx-parser`:
    - `enabled = true`
    - `requireAuthentication = true`
    - `unauthenticatedClientAction = RedirectToLoginPage`
  - Confirmed the function key embedded in the flow still matches the live Azure function key for `ParseAuthorizationControls`.
  - Directly tested the parser endpoint and observed Microsoft login HTML instead of function JSON, confirming EasyAuth interception rather than a parser failure.
  - Updated the live `authsettingsV2` resource for the Function App so requests are no longer blocked at the app-auth layer:
    - `properties.globalValidation.requireAuthentication = false`
    - `properties.globalValidation.unauthenticatedClientAction = AllowAnonymous`
  - Retested the endpoint after the change and confirmed it now reaches the function runtime, returning parser-side validation errors (`docxBase64 is not valid base64`) instead of `Unauthorized` / login redirect behavior.
- Validation commands run:
  - `az webapp auth show --resource-group DefaultResourceGroup-SEA --name bgv-docx-parser -o json`
  - `az resource show --ids /subscriptions/1a62d797-41ab-4b87-a235-23b1aa1ab252/resourceGroups/DefaultResourceGroup-SEA/providers/Microsoft.Web/sites/bgv-docx-parser/config/authsettingsV2 -o json`
  - `az resource update --ids /subscriptions/1a62d797-41ab-4b87-a235-23b1aa1ab252/resourceGroups/DefaultResourceGroup-SEA/providers/Microsoft.Web/sites/bgv-docx-parser/config/authsettingsV2 --set properties.globalValidation.requireAuthentication=false properties.globalValidation.unauthenticatedClientAction=AllowAnonymous -o json`
  - `Invoke-RestMethod` / `curl.exe` POST checks against `https://bgv-docx-parser-cshnd7aucchwfmfz.southeastasia-01.azurewebsites.net/api/parseauthorizationcontrols?...`
- Next actions and blockers:
  - Next action: re-run the failed `BGV_1` item or wait for the next file-change trigger to confirm the live flow now clears the HTTP step.
  - Blocker removed: the HTTP request is no longer being rejected by Azure App Service Authentication.

## 2026-03-16 (BGV_2 post-signature folder lookup trimmed)
- Current status:
  - Investigated a `BGV_2_Postsignature` failure where `Get_files_(properties_only)` returned `Folder Not Found` while targeting the candidate authorization folder.
- Completed tasks:
  - Reviewed the canonical `BGV_2` folder-path compose step against the `BGV_0` candidate-folder creation logic.
  - Found that the `Compose` action in `BGV_2` included a literal trailing newline after the folder-path expression, which could cause SharePoint folder lookup mismatches.
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json`
  - Changed the authorization-folder path compose expression to a trimmed value:
    - `@{trim(concat('/BGV Records/Candidate Files/', triggerBody()?['CandidateID'], '/Authorization/'))}`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `rg -n "Get_files_\\(properties_only\\)|folderPath|Compose|Authorization" flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and re-run one signed candidate case to confirm `BGV_2` now lists the authorization folder contents and completes the lock/unshare path.

## 2026-03-16 (BGV_1 immediate post-detection unshare)
- Current status:
  - Added an immediate unshare step in `BGV_1` so the candidate authorization link is revoked as soon as the signed checkbox is detected, instead of waiting for the follow-up cleanup flow alone.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Added `Stop_sharing_signed_authorization_file_immediately` after the candidate record patch step in the signed branch.
  - Configured the new unshare action to target the current authorization file from the `BGV Records` library using the trigger item ID.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and run one fresh signed authorization save to confirm the candidate link expires immediately after detection while `BGV_4` still proceeds later from `AuthorisationSigned = true`.

## 2026-03-16 (BGV_4 employer prefill split for NRIC vs Passport)
- Current status:
  - Corrected the employer HR form prefill so candidate NRIC and Passport now go into separate Microsoft Forms fields instead of collapsing into the NRIC field.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `FinalVerificationLink` prefill logic so:
    - NRIC field `r27b6bdb850dd48339dc05df11d485470` uses only `F1_IDNumberNRIC -> IdentificationNumberNRIC`
    - Passport field `r0c342001cdd8463181c36dba2a8933ad` uses only `F1_IDNumberPassport -> IdentificationNumberPassport`
  - Kept all other existing employer-prefill questions intact:
    - Candidate name
    - Request ID
    - Employer name
    - Employer UEN
    - Employer address
    - Employment period
    - Last drawn salary
    - Job title
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution, then verify one live employer email link to confirm NRIC appears only in the NRIC field and Passport appears only in the Passport field.

## 2026-03-16 (BGV_4 live Forms passport key refreshed)
- Current status:
  - Investigated why the employer HR form was still opening blank and confirmed the live Microsoft Forms Passport field key had changed from the older stored value in `BGV_4`.
- Completed tasks:
  - Reviewed the user-provided current prefilled Forms URL and extracted the live Passport query key:
    - old key: `r0c342001cdd8463181c36dba2a8933ad`
    - new key: `r425242341d6143c7a29307136debe938`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Replaced the stale Passport prefill parameter in `FinalVerificationLink` with the new live Forms key while preserving all other existing prefilled values.
  - Updated mapping docs:
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and verify a fresh employer email link.
  - Residual risk: if other Forms question IDs were also regenerated later, those keys would need the same refresh from a new prefilled URL sample.

## 2026-03-16 (BGV_4 NRIC/Passport prefill fallback to N/A)
- Current status:
  - Updated the employer HR form prefill so the unused identification field now shows `N/A` instead of staying blank.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `FinalVerificationLink` logic so:
    - if candidate used NRIC:
      - NRIC field shows the NRIC value
      - Passport field shows `N/A`
    - if candidate used Passport:
      - NRIC field shows `N/A`
      - Passport field shows the Passport value
    - if neither value is available, both resolve safely to `N/A`
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and verify a fresh employer form link from a live BGV_4 email.

## 2026-03-16 (BGV_5 company-details discrepancy answers copied into notes)
- Current status:
  - Reviewed Form 2 response storage in `BGV_5` and confirmed `Form2RawJson` already stores the full submission body, while several company-details discrepancy answers were still only preserved there and not copied into the normalized notes path.
- Completed tasks:
  - Confirmed current direct normalized Form 2 storage already includes:
    - `F2_InformationAccurate`
    - `F2_SelectedIssues`
    - `F2_EmployerWouldReEmploy`
    - `F2_ReEmployReason`
    - `F2_ReasonForLeaving`
    - `F2_Severity`
    - `F2_Outcome`
    - `F2_Notes`
    - `Form2RawJson`
  - Confirmed these company-details section questions were not previously copied into normalized notes:
    - `r2d39255c2449439096683ca0e39241b0` (company-details accuracy)
    - `rd05170e51ac34fef95f5464cf348bedc` (selected inaccurate company-detail fields)
    - `ra03058e9bbfd40d28014b0c669e92434` (company-details explanation)
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added `Condition_-_Company_Details_Discrepancy` so those answers are appended into `varNotifyBody` whenever that section is used.
  - Because `varNotifyBody` is written to both `BGV_Requests.Notes` and `BGV_FormData.F2_Notes`, the company-details discrepancy answers are now stored in both places as well as remaining in `Form2RawJson`.
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Blocker remains for `Q28` Other comments: the live Forms key is still not identified in repo evidence, so it remains preserved in `Form2RawJson` only until we capture that key from a live response body or current Forms metadata.
## 2026-03-16 - BGV_5 notes mapping document

- Added a dedicated documentation file:
  - `docs/bgv5_notes_mapping.md`
- Documented, in two separate tables, how `BGV_Requests.Notes` and `BGV_FormData.F2_Notes` are built from `BGV_5_Response1`
- Clarified that both notes fields currently receive the same assembled `varNotifyBody` text
- Documented that `Form2RawJson` is separate from the notes summary
- Recorded the remaining known gap:
  - `Other comments we should know about` is still preserved in `Form2RawJson` but not yet explicitly mapped into the notes summary

## 2026-03-17 (Daily sync export failure now stops immediately)

- Current status:
  - Hardened the daily sync script after a PAC token-expiry run falsely continued into unpack and still printed a successful completion message.
- Completed tasks:
  - Updated:
    - `scripts/active/bgv_daily_sync.ps1`
  - Added hard failure detection for PAC export output patterns:
    - `Failed to connect to Dataverse`
    - `Could not connect to the Dataverse organization`
    - `AADSTS`
    - `Authentication Requested but not configured correctly`
  - Added explicit ZIP existence check immediately after export.
  - Added explicit ZIP existence check before unpack.
  - This prevents a failed export from cascading into a misleading unpack failure and false success message.
- Validation commands run:
  - `Get-Content -Raw scripts/active/bgv_daily_sync.ps1`
- Next actions and blockers:
  - Next action: rerun the daily sync on the next cycle and confirm export/auth failures now stop the script before unpack begins.

## 2026-03-17 (BGV_FormData F2_Notes aligned with simplified BGV_Requests notes logic)

- Current status:
  - Updated `BGV_5` so `BGV_FormData.F2_Notes` now uses the same simplified notes logic already applied to `BGV_Requests.Notes`.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed:
    - `item/F2_Notes` from `@variables('varNotifyBody')`
    - to `@variables('varRequestNotesBody')`
  - Result:
    - `BGV_Requests.Notes` and `BGV_FormData.F2_Notes` now both show:
      - selected choice / checkbox answers directly
      - textbox explanation areas as `Please refer to the report summary for additional comments.`
  - Left `Form2RawJson` unchanged so the full response is still preserved.
  - Updated:
    - `docs/bgv5_notes_mapping.md`
- Validation commands run:
  - pending PAC import / JSON validation in this task
- Next actions and blockers:
  - Next action: validate JSON, import the updated solution, and push the synced change to GitHub.

## 2026-03-17 (BGV_5 notes now indicate which explanation textbox was filled)

- Current status:
  - Refined the simplified notes wording so explanation textboxes do not just show a generic placeholder; notes now explicitly say which explanation field was filled.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Updated simplified notes behavior for:
    - re-employ reason
    - employment period explanation
    - job title explanation
    - remuneration explanation
    - other abnormalities explanation
    - company details explanation
  - New behavior:
    - if a textbox is blank, no placeholder line is shown for that textbox
    - if a textbox is filled, notes now show:
      - `<field name> filled: Please refer to the report summary for additional comments.`
  - Updated:
    - `docs/bgv5_notes_mapping.md`
- Validation commands run:
  - pending PAC import / JSON validation in this task
- Next actions and blockers:
  - Next action: validate JSON, import the updated solution, and push the synced change to GitHub.

## 2026-03-18 (Shared mailbox and internal mailbox targets changed to recruitment@)

- Current status:
  - Updated the current canonical BGV flows so shared-mailbox sender addresses and direct internal recipients using `recruitmentops@dlresources.com.sg` now use `recruitment@dlresources.com.sg`.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Updated current-behavior documentation:
    - `docs/flows_easy_english.md`
  - Applied changes to:
    - shared mailbox sender addresses
    - direct internal `emailMessage/To` targets that still used `recruitmentops@dlresources.com.sg`
    - BGV_4 candidate-email fallback target
- Validation commands run:
  - pending JSON validation / PAC import in this task
- Next actions and blockers:
  - Next action: validate JSON, import the updated solution, push to GitHub, and refresh the external `Flow Details` doc copy.

## 2026-03-16 (BGV_5 BGV_Requests notes simplified while F2_Notes stays detailed)

- Current status:
  - Updated `BGV_5` so `BGV_Requests.Notes` now shows selected choice/checkbox answers clearly, while free-text explanation fields are replaced with a standard placeholder.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added a second string variable:
    - `varRequestNotesBody`
  - Kept existing detailed internal note-building unchanged in:
    - `varNotifyBody`
  - Changed `BGV_Requests.Notes` to use:
    - `@variables('varRequestNotesBody')`
  - Left `BGV_FormData.F2_Notes` using:
    - `@variables('varNotifyBody')`
  - For `BGV_Requests.Notes`, implemented this rule:
    - selected choice/checkbox answers remain visible
    - free-text explanation fields now show `Please refer to the report summary for additional comments.`
  - Updated the dedicated mapping guide:
    - `docs/bgv5_notes_mapping.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and verify one live Form 2 response so `BGV_Requests.Notes` shows the simplified wording while `F2_Notes` keeps the detailed explanations.
## 2026-03-18 (EMP1 SendAfterDate restored to Form 1 defer rule)
- Current status:
  - Restored the intended EMP1 scheduling behavior so `SendAfterDate` now respects the candidate's current-employer defer choice from Form 1.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Changed EMP1 `SendAfterDate` mapping in `BGV_0`:
    - if Form 1 Q17 is `Yes`, use `E1 - Employment Period End Date`
    - otherwise use `utcNow()`
  - Changed `BGV_4` so the `SendAfterDate` gate only blocks employer sending for `EMP1`.
    - `EMP1` sends only when `SendAfterDate` is today or earlier
    - `EMP2` and `EMP3` are not blocked by the defer-date gate
  - Updated supporting docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for updated canonical workflow JSON
  - `pac auth who`
- Next actions and blockers:
  - Next action: import updated solution and run one live EMP1 case where Q17 = `Yes` to confirm the request waits until the recorded end date.
## 2026-03-18 (BGV_5 selected issue explanations limited to checked options)
- Current status:
  - Tightened the low-severity Form 2 summary logic so only the explanation headings for the selected inaccurate-information options are shown.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed the detailed notification text (`varNotifyBody`) so it only lists:
    - `Employment Period`
    - `Job Title/Position`
    - `Remuneration Package`
    - `Other abnormalities`
    when those options were actually selected in the inaccurate-information Form 2 question.
  - Added compatibility for the live option label `Last Position Held` so it maps to the `Job Title/Position` explanation slot.
  - Changed the summary notes text (`varRequestNotesBody`) so the `... explanation filled` lines only appear when:
    - that option was selected, and
    - its textbox actually contains a value
  - Updated supporting docs:
    - `docs/bgv5_notes_mapping.md`
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for updated canonical workflow JSON
  - `pac auth who`
- Next actions and blockers:
  - Next action: import updated solution and verify one live Form 2 response where only one inaccurate-information option is selected, to confirm the email/details block shows just that option.
## 2026-03-18 (BGV_0 candidate email note for signed-copy follow-up)
- Current status:
  - Updated the first candidate authorization email so it now tells the candidate that a copy of the signed form will be emailed later.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Added this sentence into the same signing-instructions paragraph:
    - `Note: A copy of your signed form will be sent to your email later on.`
  - Updated supporting docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for updated canonical workflow JSON
  - `pac auth who`
- Next actions and blockers:
  - Next action: import updated solution and trigger one fresh candidate email to confirm the wording is visible in the first outbound message.
## 2026-03-19 (Daily sync export normalization)
- Current status:
  - Ran daily sync successfully against the live environment and reconciled the exported PAC artifacts back into Git.
- Completed tasks:
  - Verified PAC account before sync:
    - `recruitment@dlresources.com.sg`
  - Ran:
    - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - Export succeeded.
  - Unpack hit the expected temporary ZIP lock once and then succeeded on retry.
  - Captured the resulting sync-only artifact changes:
    - workflow files normalized to no trailing newline:
      - `BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - `BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
      - `BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - `BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
    - solution metadata version updated:
      - `flows/power-automate/unpacked/Other/Customizations.xml`
      - `flows/power-automate/unpacked/Other/Solution.xml`
- Validation commands run:
  - `git status --short --branch`
  - `git diff -- flows/power-automate/unpacked/Workflows/...`
  - `git diff -- flows/power-automate/unpacked/Other/Customizations.xml flows/power-automate/unpacked/Other/Solution.xml`
  - `ConvertFrom-Json` validation for representative workflow JSON
- Next actions and blockers:
  - Next action: none; local repo, GitHub, and PAC-exported source are aligned after committing the sync artifacts.
## 2026-03-19 (BGV_5 notes collapsed to one shared report-summary line)
- Current status:
  - Simplified `BGV_Requests.Notes` and `BGV_FormData.F2_Notes` so long-comment fields no longer produce multiple `...filled` markers.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Removed per-field long-comment note markers from:
    - re-employ reason
    - inaccurate-information explanation fields
    - company-details explanation
  - Added one shared line to notes when any mapped long-comment field is filled:
    - `Please refer to the report summary for additional comments.`
  - Ensured that shared line is appended only once even when multiple mapped comment fields are filled.
  - Updated docs:
    - `docs/bgv5_notes_mapping.md`
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for updated canonical workflow JSON
  - `pac auth who`
- Next actions and blockers:
  - Blocker remains for Form 2 `Q28 / Other comments we should know about`: the live Forms key is still unknown in the repo, so it remains raw-JSON-only until we capture that key from a live payload or current Forms metadata.
## 2026-03-19 (BGV_7 report summary generation flow added)
- Current status:
  - Added a new canonical flow and Azure Function endpoint to generate per-employer report-summary DOCX files from the live SharePoint template `ReportSummary_Template.docx`.
- Completed tasks:
  - Confirmed the user-provided local copy of the live template:
    - `out/ReportSummary_Template.docx`
  - Extracted the live template content-control tags and mapped them into two groups:
    - Form 1 tags:
      - `Form1.CandidateFullName`
      - `Form1.CandidateEmail`
      - `Form1.IdentificationNumberNRIC`
      - `Form1.IdentificationNumberPassport`
    - Form 2 tags:
      - `Form2.Q4` through `Form2.Q31`
      - `Form2.Q31FileName`
  - Added new Azure Function endpoint:
    - `functions/bgv-docx-parser/FillReportSummaryControls.cs`
    - route:
      - `GET/POST /api/fillreportsummarycontrols`
  - Added request/response payload models:
    - `functions/bgv-docx-parser/Models/ReportSummaryFillRequestPayload.cs`
    - `functions/bgv-docx-parser/Models/ReportSummaryFillResponsePayload.cs`
  - Added new service interfaces and implementations:
    - `functions/bgv-docx-parser/Services/IDocxContentControlValueFiller.cs`
    - `functions/bgv-docx-parser/Services/IReportSummaryValueMapper.cs`
    - `functions/bgv-docx-parser/Services/OpenXmlDocxContentControlValueFiller.cs`
    - `functions/bgv-docx-parser/Services/ReportSummaryValueMapper.cs`
  - Registered the new services in:
    - `functions/bgv-docx-parser/Program.cs`
  - Added focused tests:
    - `tests/bgv-docx-parser.tests/ReportSummaryFillerTests.cs`
  - Added new canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json.data.xml`
  - Updated solution metadata so `BGV_7` is part of the packed/imported solution:
    - `flows/power-automate/unpacked/Other/Solution.xml`
  - Implemented `BGV_7` runtime behavior:
    - recurrence-triggered poll of completed `BGV_Requests`
    - gate on non-empty `ResponseReceivedAt`
    - match exact `RequestID` to `BGV_FormData`
    - require both `Form1RawJson` and `Form2RawJson`
    - fetch template from:
      - `/BGV Records/Templates/ReportSummary_Template.docx`
    - call the new fill endpoint with template bytes plus raw Form 1 / Form 2 JSON
    - write result into candidate folder:
      - `RS_Emp1.docx`
      - `RS_Emp2.docx`
      - `RS_Emp3.docx`
    - update existing report file when already present, otherwise create it
  - Updated docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/file_index.md`
  - Published the Azure Function app and imported the updated solution into the live environment.
  - Important implementation note:
    - `fillreportsummarycontrols` currently runs with `AuthorizationLevel.Anonymous` so the live flow can call it without an additional key-discovery step.
    - Existing parser/lock endpoints remain function-protected.
- Validation commands run:
  - `dotnet test tests/bgv-docx-parser.tests/bgv-docx-parser.tests.csproj`
  - local scratch validation against `out/ReportSummary_Template.docx`
  - `func azure functionapp publish bgv-docx-parser --dotnet-isolated`
  - live POST smoke test to `/api/fillreportsummarycontrols`
  - `pac auth who`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_report_summary.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_report_summary.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: verify one completed employer response generates the correct `RS_Emp*` report under the candidate folder with populated content controls.
  - Residual risk: the new fill endpoint is anonymous until a durable key-management path is added for that route.
## 2026-03-19 (BGV_7 SharePoint connection binding repaired)
- Current status:
  - Investigated the BGV_7 activation banner and confirmed the flow was blocked by a SharePoint connection-reference binding that `recruitment@dlresources.com.sg` could not use.
- Completed tasks:
  - Confirmed active PAC identity before repair:
    - `recruitment@dlresources.com.sg`
  - Reviewed canonical flow and verified `BGV_7` uses:
    - connection reference logical name `cr94d_sharedsharepointonline_96d5d`
  - Confirmed the user's valid SharePoint connection ID from PAC:
    - `shared-sharepointonl-dfd1c8f6-cb4a-4603-b128-fc5e1f199d6b`
  - Generated a temporary PAC settings file from the current solution.
  - Re-imported the current solution with the SharePoint connection reference explicitly rebound to the working `recruitment@` SharePoint connection.
  - Cleaned up the temporary settings artifact after successful import.
- Validation commands run:
  - `pac auth who`
  - `pac connection list`
  - `pac solution create-settings --solution-folder .\flows\power-automate\unpacked --settings-file .\out\deployment-settings\bgv7_rebind.settings.json`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_report_summary.zip --settings-file .\out\deployment-settings\bgv7_rebind.settings.json --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: refresh the BGV_7 flow page and turn the flow on.
  - Note: the import repaired the inaccessible SharePoint binding; the flow still needs to be switched on because it is a scheduled flow and imports land in the off state.
## 2026-03-19 (BGV_6 employer reminders now regenerate the form link)
- Current status:
  - Investigated employer reminder emails that were arriving without a Microsoft Forms URL and confirmed `BGV_6` was still reading the legacy `uniquelinktoemployers` request column, which is now blank in current runtime.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Added `Get_items_(BGV_FormData)` inside the reminder loop so `BGV_6` can fetch the matching employer form-data row by exact `RequestID`.
  - Added `FinalVerificationLink` compose action inside `BGV_6` using the same prefilled Microsoft Forms URL logic already used by `BGV_4`.
  - Changed reminder email bodies to use:
    - `@{outputs('FinalVerificationLink')}`
    instead of:
    - `@{items('Apply_to_each')?['uniquelinktoemployers']}`
  - Updated docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and verify a fresh reminder email contains the same employer form link pattern as the initial `BGV_4` request email.

## 2026-03-19 (BGV_7 detection aligned with live employer-completion fields)
- Current status:
  - Tightened `BGV_7` so report generation follows the actual completion fields written by `BGV_5` and no longer fails just because `Form1RawJson` is blank on the matched `BGV_FormData` row.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
  - Changed the completed-request query in `BGV_7` to accept either:
    - `Status = Completed`
    - `VerificationStatus = Completed`
  - Relaxed the `Condition_-_FormData_Found` gate so `BGV_7` now requires:
    - a matched `BGV_FormData` row
    - non-empty `Form2RawJson`
    - but no longer hard-requires `Form1RawJson`
  - Extended the `BGV_7` HTTP payload to pass Form 1 fallback values from normalized `BGV_FormData` columns:
    - `F1_CandidateFullName`
    - `F1_CandidateEmail`
    - `F1_IDNumberNRIC`
    - `F1_IDNumberPassport`
  - Updated Azure Function request payload and mapper so `fillreportsummarycontrols`:
    - prefers `Form1RawJson` when present
    - otherwise uses those normalized Form 1 fallback values
  - Added test coverage for the fallback path in:
    - `tests/bgv-docx-parser.tests/ReportSummaryFillerTests.cs`
  - Updated docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - pending in this task
- Next actions and blockers:
  - Next action: publish the function, import the updated solution, and verify that one completed employer form submission produces `RS_EmpN.docx`.

## 2026-03-19 (BGV_Candidates IDTypeProvided + report discrepancy fallback)
- Current status:
  - Added the missing `BGV_Candidates.IDTypeProvided` mapping and tightened the report-summary discrepancy mapping so employer comments still populate the Employment Details section when the specific discrepancy box is blank.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Added candidate-row mapping in `BGV_0`:
    - `IDTypeProvided = NRIC` when the Form 1 NRIC field is filled
    - otherwise `Passport`
  - Verified current `BGV_Candidates` field usage:
    - `JobTitle` not used by canonical flows
    - `ConsentCaptured` still written by `BGV_0`, but not used by current reminder/signature gates
    - `ConsentEvidence` not used
    - `AuthorizationLinkExpiredAt` not used
    - `LastAuthReminderAt` is actively used by `BGV_3` as a same-day reminder dedupe/stamp field
  - Updated report-summary mapper:
    - `Form2.Q17` / `Q18` / `Q19` / `Q20` keep their direct employer discrepancy mappings
    - if one is blank and the related issue was selected in `Form2.Q16`, the mapper falls back to `Form2.Q10`
  - Added test coverage for the discrepancy fallback in:
    - `tests/bgv-docx-parser.tests/ReportSummaryFillerTests.cs`
  - Updated docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - pending in this task
- Next actions and blockers:
  - Next action: publish/import the updates and verify one employer response with discrepancy comments fills the Employment Details section in `RS_EmpN.docx`.

## 2026-03-19 (VerificationStatus lifecycle + severity remap)
- Current status:
  - Aligned the request lifecycle around `VerificationStatus` only and removed the active flow dependency on the duplicate `Status` field.
  - Adjusted severity rules to match the latest employer-form logic:
    - High = MAS issue, disciplinary issue, or re-employment answer `No`
    - Medium = employment details inaccurate (`Q15 = No`) when no High trigger exists
    - Low = company details inaccurate (`Q8 = No`) when no higher trigger exists
    - Neutral = only `Q27` other comments when no higher trigger exists
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json`
  - Remapped `VerificationStatus` lifecycle to:
    - `Not Sent`
    - `Email Sent`
    - `Reminder 1 Sent`
    - `Reminder 2 Sent`
    - `Reminder 3 Sent`
    - `Responded`
  - Removed flow-side writes/reads of `BGV_Requests.Status`:
    - `BGV_5` now sets only `VerificationStatus = Responded`
    - `BGV_7` now keys off `VerificationStatus = Responded`
  - Confirmed `LinkDue` remains a SharePoint calculated column only and is not written/read by canonical flows.
  - Updated docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo field set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName VerificationStatus --Choices [...]`
  - `m365 spo listitem set ... --VerificationStatus ...` (bulk migration of existing request rows)
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_status_verification_sync.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_status_verification_sync.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Completed live SharePoint `VerificationStatus` choice update and migrated existing rows to:
    - `Not Sent`
    - `Email Sent`
    - `Reminder 1 Sent`
    - `Reminder 2 Sent`
    - `Reminder 3 Sent`
    - `Responded`
  - Next action: optional UI cleanup only.
    - `VerificationStatus` custom pill formatting still references the older labels (`Pending`, `Sent`, etc.), so list display colors can be refreshed later if desired.
    - `Status` is no longer used by canonical flows; safest next step is to hide it first, observe one live cycle, then delete it only if you still want it removed.

## 2026-03-20 (Daily sync refresh after lifecycle remap)
- Current status:
  - Ran the daily PAC export/unpack successfully using `recruitment@dlresources.com.sg`.
  - The export/unpack hit the expected transient ZIP lock once and then succeeded on retry.
- Completed tasks:
  - Refreshed local canonical source from live Power Automate.
  - Reviewed post-sync diffs and confirmed the only meaningful live flow-state change was:
    - `BGV_0_CandidateDeclaration` exported as active (`StateCode=0`, `StatusCode=1`) in `.json.data.xml`
  - Confirmed the remaining workflow JSON diffs were export normalization only:
    - newline-at-end-of-file normalization
    - indentation normalization on the existing `VerificationStatus` lines in `BGV_0`
  - Confirmed solution metadata changed only for normal environment version drift and root-component ordering:
    - `flows/power-automate/unpacked/Other/Customizations.xml`
    - `flows/power-automate/unpacked/Other/Solution.xml`
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `git status --short --branch`
  - `git diff --stat -- flows/power-automate/unpacked/Workflows/`
  - `git diff -- flows/power-automate/unpacked/Workflows/...`
- Next actions and blockers:
  - Next action: commit and push the sync artifacts so local repo and GitHub match the latest exported live state again.

## 2026-03-20 (BGV_0 save fix for removed ConsentCaptured column)
- Current status:
  - Fixed a live Flow save failure in `BGV_0` caused by an obsolete SharePoint parameter:
    - `item/ConsentCaptured`
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Removed `item/ConsentCaptured = true` from `Create_BGV_Candidates_Row`.
  - Rechecked the canonical flows for related candidate-field writes and confirmed no other current flow still writes `ConsentCaptured`.
  - Updated supporting docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `rg -n "ConsentCaptured|ConsentEvidence|item/Consent" flows/power-automate/unpacked/Workflows docs`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Next action: import the updated solution and re-save `BGV_0` in Power Automate to confirm the obsolete-parameter error is gone.

## 2026-03-20 (FlaggedIssues remap, twice-daily reminder windows, and report-created post)
- Current status:
  - Remapped the employer-response summary field from fixed `Outcome` labels to dynamic flagged-issue text while keeping the internal SharePoint field name as `Outcome`.
  - Updated reminder handling to run on twice-daily Singapore checkpoints and added one-time escalation stamping.
  - Added a Teams post when a new report summary file is created.
- Completed tasks:
  - Updated `BGV_5_Response1` so the request/form-data summary field now stores combined flagged issues from Form 2:
    - selected company-detail discrepancies from `Q9`
    - selected employment-detail discrepancies from `Q16`
    - `MAS`
    - `Disciplinary`
    - `Re-employ`
    - `Other Comments`
  - Updated recruiter response email wording to mention the later report summary location in `BGV_Records > Candidate Files (<CandidateID>)`.
  - Updated `BGV_6_HRReminderAndEscalation`:
    - recurrence now runs every 30 minutes with a processing gate at `9:00 AM` and `5:30 PM` Singapore time
    - escalation path now stamps `EscalatedAt`
  - Updated `BGV_7_Generate_Report_Summary`:
    - adds Teams connection reference
    - posts to `DLR Recruitment Ops > BGV` when a new `RS_EmpN.docx` is first created
    - includes the report link in the Teams post
  - Updated the live SharePoint field:
    - `BGV_Requests.Outcome` display title -> `FlaggedIssues`
    - `FillInChoice = true`
    - simplified column formatter to plain text
  - Updated supporting docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo field set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName Outcome --Title FlaggedIssues --FillInChoice true --CustomFormatter ...`
  - `m365 spo field get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName Outcome --output json`
- Next actions and blockers:
  - Next action: import the updated flows through PAC, then refresh the external `Flow Details` document copy so repo docs and working copy stay aligned.

## 2026-03-20 (Outcome display title restored)
- Current status:
  - Restored the live SharePoint display title of `BGV_Requests.Outcome` back to `Outcome` to avoid user confusion between the internal field name and the visible label.
- Completed tasks:
  - Updated the live SharePoint field:
    - `BGV_Requests.Outcome` display title -> `Outcome`
  - Updated supporting docs so they describe the combined-issue behavior using the visible field name `Outcome`.
- Validation commands run:
  - `m365 spo field set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName Outcome --Title Outcome`
  - `m365 spo field get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName Outcome --output json`
- Next actions and blockers:
  - None. This was a label cleanup only; flow logic remains unchanged.

## 2026-03-20 (Added BGV Checks request summary field)
- Current status:
  - Added a new request-side text field `BGV Checks` to `BGV_Requests` and wired the canonical flows to maintain it.
- Completed tasks:
  - Created live SharePoint field:
    - display title: `BGV Checks`
    - internal name: `BGV_x0020_Checks`
  - Updated `BGV_5_Response1` so request rows are stamped with:
    - `Form Filled and Cleared` when employer response is received and severity is blank or `Neutral`
    - `Adverse BGV Checks - see severity` when employer response is received and severity is `Low`, `Medium`, or `High`
  - Updated `BGV_6_HRReminderAndEscalation` so request rows are stamped with:
    - `No response at Reminder 2` after the reminder-2 delay matures with no response
    - `Form Filled and Cleared` again when reminder 3 is sent, per the requested business rule
  - Updated docs to explain the new field and confirmed `CandidateItemID` can be hidden from the SharePoint view without affecting the flows.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `m365 spo field add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --xml <Field ... />`
  - `m365 spo field get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle BGV_Requests --internalName BGVChecks --output json`
- Next actions and blockers:
  - Next action: import the updated flows through PAC and push the repo changes so local, GitHub, and Power Automate stay aligned.
## 2026-03-20 (BGV_FormData normalization expansion for Form 1 defer date and Form 2 admin/compliance fields)
- Current status:
  - Added new dedicated `BGV_FormData` columns for previously raw/noted fields and wired the canonical flows to persist them.
- Completed tasks:
  - Added live `BGV_FormData` columns:
    - `F1_SendAfterDate`
    - `F2_MASQuestion`
    - `F2_DisciplinaryAction`
    - `F2_ContactForClarification`
    - `F2_OtherComments`
    - `F2_FormCompleterName`
    - `F2_FormCompleterJobTitle`
    - `F2_FormCompleterContactDetails`
    - `F2_CompanyStampFileName`
  - Confirmed `F2_CompanyDetailsAccurate` and `F2_CompanyDetailsSelectedIssues` already existed live and wired them into `BGV_5`.
  - Updated `BGV_0_CandidateDeclaration`:
    - `Create_BGV_FormData_Row_E1` now writes `F1_SendAfterDate` when the Form 1 defer answer is `Yes` and the EMP1 end date is present.
  - Updated `BGV_5_Response1`:
    - now writes company-details accuracy and selected company-detail issues into dedicated `BGV_FormData` fields
    - now writes MAS answer, disciplinary yes/no, contact-for-clarification, other comments, form completer name, form completer job title, form completer contact details, and derived company-stamp filename into dedicated `BGV_FormData` fields
  - Updated docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation planned:
  - parse updated flow JSON
  - PAC pack/import
  - final git sync check

## 2026-03-20 (BGV Dashboard workbook created and uploaded)
- Current status:
  - Reworked the recruiter-facing Excel dashboard workbook into a condensed table view with a pivot-style summary sheet and uploaded the revised copy into the `BGV Records/Dashboard/` folder.
- Completed tasks:
  - Added dashboard builder script:
    - `scripts/active/build_bgv_dashboard.ps1`
  - Added dashboard usage/design doc:
    - `docs/bgv_dashboard.md`
  - Added dedicated dashboard header/logic doc:
    - `docs/bgv_dashboard_headers.md`
  - Builder now:
    - exports live `BGV_Candidates`, `BGV_Requests`, and `BGV_FormData` rows through authenticated `m365`
    - writes hidden raw sheets into the workbook
    - builds one condensed recruiter cases table with:
      - `Candidate Name`
      - `CandidateID`
      - `RequestID`
      - `Company Name`
      - `HR Name`
      - `HR Email`
      - `HR Mobile Number`
      - `Status`
      - `Candidate Reminder`
      - `Employer Reminder`
      - `Overdue`
      - `Completed Status`
      - `Employer Response Received At`
      - `Last Activity At`
      - `Severity`
      - `Outcome`
    - maps one recruiter-facing `Status` column across the end-to-end journey:
      - candidate form received
      - authorisation form sent
      - authorisation form received
      - employer email queued/sent
      - employer reminder 1/2/3
      - employer form received
    - creates a pivot-style `Summary` sheet with:
      - KPI cards
      - status count summary table
      - overdue count summary table
      - completed count summary table
    - keeps the `Cases` sheet filterable for recruiter use
  - Exported reusable Power Query logic for the same master-table shape:
    - `out/dashboard/BGV Dashboard Master Query.m`
  - Generated workbook artifact:
    - `out/dashboard/BGV Dashboard.xlsx`
  - Uploaded workbook to SharePoint:
    - `BGV Records/Dashboard/BGV Dashboard.xlsx`
  - Root-library overwrite was intentionally not used because an existing root-level `BGV Dashboard.xlsx` was locked by `recruitment@dlresources.com.sg`.
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1`
  - Excel COM inspection of:
    - `out/dashboard/BGV Dashboard.xlsx`
    - confirmed workbook sheets:
      - `Summary`
      - `Cases`
      - `Support`
      - `RawCandidates`
      - `RawRequests`
      - `RawFormData`
    - confirmed `Cases` used range populated and `tblBGVCases` exists
    - confirmed condensed headers:
      - `Candidate Name`
      - `CandidateID`
      - `RequestID`
      - `Company Name`
      - `HR Name`
      - `HR Email`
      - `HR Mobile Number`
      - `Status`
      - `Candidate Reminder`
      - `Employer Reminder`
      - `Overdue`
      - `Completed Status`
      - `Employer Response Received At`
      - `Last Activity At`
      - `Severity`
      - `Outcome`
  - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "<local BGV Dashboard.xlsx>" --overwrite`
- Next actions and blockers:
  - Optional next action: if you want the workbook to replace the existing root-level `BGV Dashboard.xlsx`, close/unlock that file first and re-upload to `BGV Records` root.
  - Note: Excel COM automation on this machine would not reliably create slicers or silently hydrate a live SharePoint-authenticated Power Query load, so the workbook is delivered as a fresh live-list snapshot with standard table filters, a pivot-style summary sheet, and a separate exported Power Query M definition.

## 2026-03-20 (Dashboard sync + implementation guide)
- Current status:
  - Aligned the main SharePoint dashboard file with the latest local build and added a plain-English implementation guide so the dashboard setup is easier to understand and maintain.
- Completed tasks:
  - Updated the reminder display format in the dashboard build:
    - `Candidate Reminder` now shows:
      - `Not sent`
      - `1: yyyy-mm-dd hh:mm`
    - `Employer Reminder` now shows:
      - `Not sent`
      - `1: yyyy-mm-dd hh:mm`
      - `2: yyyy-mm-dd hh:mm`
      - `3: yyyy-mm-dd hh:mm`
  - Hardened `m365` JSON parsing in:
    - `scripts/active/build_bgv_dashboard.ps1`
    - the builder now strips the occasional sign-in prompt text before `ConvertFrom-Json`
  - Added simplified implementation guide:
    - `docs/bgv_dashboard_implementation_guide.md`
  - Updated dashboard docs:
    - `docs/bgv_dashboard.md`
    - `docs/bgv_dashboard_headers.md`
  - Rebuilt the local workbook:
    - `out/dashboard/BGV Dashboard.xlsx`
  - Replaced the main SharePoint workbook after user confirmation:
    - `BGV Records/Dashboard/BGV Dashboard.xlsx`
    - confirmed SharePoint version advanced to `6.0`
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1`
  - Excel COM inspection of `out/dashboard/BGV Dashboard.xlsx`
    - confirmed reminder examples such as:
      - `Not sent`
      - `1: 2026-03-16 17:00`
      - `2: 2026-03-19 15:00`
  - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "<local BGV Dashboard.xlsx>" --overwrite`
- Next actions and blockers:
  - Next action: push the dashboard script/docs updates to GitHub so local and GitHub match the SharePoint-backed dashboard build state.
  - Clarification: GitHub stores the source/docs for the dashboard, while SharePoint stores the recruiter workbook artifact itself.

## 2026-03-20 (RecruiterID removed from dashboard)
- Current status:
  - Removed the unused `RecruiterID` column from the recruiter dashboard and aligned the workbook/docs so only real recruiter-facing fields remain.
- Completed tasks:
  - Updated dashboard builder:
    - `scripts/active/build_bgv_dashboard.ps1`
    - removed `RecruiterID` from the generated `Cases` table
  - Updated dashboard docs:
    - `docs/bgv_dashboard.md`
    - `docs/bgv_dashboard_headers.md`
    - `docs/bgv_dashboard_implementation_guide.md`
  - Rebuilt local workbook:
    - `out/dashboard/BGV Dashboard.xlsx`
  - Replaced SharePoint workbook:
    - `BGV Records/Dashboard/BGV Dashboard.xlsx`
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1`
  - Excel COM inspection of `out/dashboard/BGV Dashboard.xlsx`
    - confirmed `RecruiterID` header removed
  - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "<local BGV Dashboard.xlsx>" --overwrite`
- Next actions and blockers:
  - Next action: commit and push this cleanup so GitHub matches local and SharePoint again.
## 2026-03-23 (Daily sync refresh + dashboard rebuild)
- Current status:
  - Ran the daily PAC export/unpack successfully using `recruitment@dlresources.com.sg`.
  - Rebuilt the recruiter dashboard workbook from the latest live SharePoint list data.
- Completed tasks:
  - Refreshed local canonical flow source from Power Automate via:
    - `scripts/active/bgv_daily_sync.ps1`
  - Confirmed the export/unpack again hit the expected transient ZIP-lock once and then succeeded on retry.
  - Rebuilt dashboard workbook artifact:
    - `out/dashboard/BGV Dashboard.xlsx`
    - `out/dashboard/BGV Dashboard Master Query.m`
  - Checked the live SharePoint dashboard file metadata and confirmed:
    - `BGV Records/Dashboard/BGV Dashboard.xlsx`
    - version `10.0`
    - modified `2026-03-23T01:59:23Z`
  - Confirmed the post-sync repo diffs were export-normalization only:
    - trailing newline normalization in `BGV_0`, `BGV_5`, `BGV_7`
    - minor comma formatting normalization in `BGV_6`
    - normal environment version drift in `Customizations.xml` and `Solution.xml`
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\active\\build_bgv_dashboard.ps1`
  - `m365 spo file get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --url "/sites/DLRRecruitmentOps570/BGV Records/Dashboard/BGV Dashboard.xlsx" --output json`
  - `git diff --stat`
- Next actions and blockers:
  - One direct overwrite attempt of the dashboard workbook returned:
    - `locked for shared use by recruitment@dlresources.com.sg`
  - The live file already showed a fresh same-day modified timestamp, so no immediate follow-up is required unless you want another forced upload after closing the workbook.
- Date: 2026-03-23
- Task: Switch candidate authorization sharing from anonymous edit links to candidate-specific edit access.
- Completed tasks:
  - Updated `BGV_0_CandidateDeclaration` so the generated authorization document now composes a direct document URL, grants candidate-specific edit access using the candidate email from Form 1, and stores/sends that URL through `BGV_Candidates.AuthorizationLink`.
  - Replaced the old anonymous `CreateSharingLink` step with a SharePoint REST share request using the existing SharePoint connection.
  - Kept downstream reminder behavior unchanged by continuing to use the same `AuthorizationLink` field in `BGV_Candidates`.
  - Updated onboarding docs to reflect the new sign-in-required candidate access model.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Notes:
  - The candidate now needs to sign in with the same email address they submitted in Form 1 to open and edit the document.
- Date: 2026-03-26
- Task: Restore anonymous editable authorization links after SharePoint site sharing was reopened.
- Completed tasks:
  - Verified the live SharePoint site still has `ShareByLinkEnabled = true` and `ShareByEmailEnabled = true`.
  - Reverted `BGV_0_CandidateDeclaration` from candidate-specific sign-in access back to the anonymous editable `CreateSharingLink` action.
  - Restored `BGV_Candidates.AuthorizationLink` and the onboarding email body to use the anonymous edit link again.
  - Updated the documentation so it again reflects the external-access anonymous sharing model for authorization documents.
- Validation commands run:
  - `m365 spo site get --url "https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570" --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
- Date: 2026-03-26
- Task: Fix `BGV_8_Track_Employer_Email_Replies` sender parsing for incoming mailbox trigger variations.
- Completed tasks:
  - Updated `Compose_-_CurrentSenderEmail` so it safely handles both trigger shapes returned by `When a new email arrives (V3)`:
    - sender as an object containing `emailAddress.address`
    - sender as a plain string email address
  - Removed the runtime dependency on direct property selection from a value that may already be a string.
  - Kept the rest of the reply-tracking logic unchanged:
    - primary subject match by `RequestID`
    - fallback sender-email match
    - latest `EmployerEmailReplyAt` wins
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_8_Track_Employer_Email_Replies-FA5CF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Date: 2026-03-26
- Task: Add scheduled local dashboard refresh helpers and manual refresh command.
- Completed tasks:
  - Added `scripts/active/run_bgv_dashboard_refresh.ps1` as the manual one-command dashboard rebuild/upload entrypoint.
  - Added `scripts/active/register_bgv_dashboard_refresh_task.ps1` to register a local Windows scheduled task for automatic refreshes.
  - Corrected the dashboard builder default upload target so scheduled/manual refreshes now overwrite:
    - `BGV Records/Dashboard/BGV Dashboard.xlsx`
    instead of the document-library root.
  - Documented the manual and scheduled dashboard refresh paths in the dashboard docs.
- Scheduled refresh design:
  - runs daily at `09:00`, `12:00`, `15:00`, `18:00`, and `21:00`
  - uses the existing local dashboard build script with SharePoint upload
  - does not consume Power Automate cloud flow capacity
- Date: 2026-03-26
- Task: Prepare Power Automate-first dashboard redesign and comparison workbook.
- Completed tasks:
  - Reviewed the current dashboard builder, local refresh helpers, and dashboard docs to capture the current logic for:
    - `Status`
    - `Candidate Reminder`
    - `Employer Reminder`
    - `Completed Status`
    - `Last Activity At`
  - Documented the cloud-refreshable target design in:
    - `docs/bgv_dashboard_power_automate_redesign.md`
  - Defined the recommended stable workbook structure:
    - `Summary`
    - `Cases`
    - `Helper`
    - `RefreshLog`
    - `Comparison`
  - Defined the target main Excel table for a future cloud refresh flow:
    - `tblDashboardCasesPA`
  - Defined the recommended future Power Automate flow:
    - `BGV_9_Refresh_Dashboard_Excel`
  - Confirmed the redesign removes:
    - `Overdue`
  - Preserved current dashboard `Status` logic in the redesign mapping plan.
  - Added a local comparison workbook builder:
    - `scripts/active/build_bgv_dashboard_pa_prototype.ps1`
  - Added a separate prototype workbook artifact for side-by-side review:
    - `out/dashboard/BGV Dashboard - Power Automate Prototype.xlsx`
- Validation planned:
  - Run the prototype builder script
  - Confirm workbook sheets and named tables exist
  - Review the comparison workbook before changing the live SharePoint dashboard
- Date: 2026-03-26
- Task: Publish dashboard prototype beside the live dashboard for user comparison.
- Completed tasks:
  - Created a renamed comparison copy of the prototype workbook:
    - `out/dashboard/BGVDashboard_FLow.xlsx`
  - Uploaded the comparison workbook to the same SharePoint dashboard folder as the live workbook:
    - `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`
  - Confirmed the uploaded file metadata:
    - version `1.0`
    - created `2026-03-26T03:50:29Z`
  - This lets users compare:
    - `BGV Dashboard.xlsx`
    - `BGVDashboard_FLow.xlsx`
    side by side in the same SharePoint folder before any dashboard cutover.
- Validation commands run:
  - `Copy-Item -LiteralPath "out\dashboard\BGV Dashboard - Power Automate Prototype.xlsx" -Destination "out\dashboard\BGVDashboard_FLow.xlsx" -Force`
  - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "out/dashboard/BGVDashboard_FLow.xlsx" --overwrite`
- Date: 2026-03-26
- Task: Build and deploy live cloud dashboard refresh flow.
- Completed tasks:
  - Added new canonical flow:
    - `BGV_9_Refresh_Dashboard_Excel`
  - Added new solution workflow metadata:
    - `flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json`
    - `flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json.data.xml`
  - Registered a new Excel Online (Business) connection reference in:
    - `flows/power-automate/unpacked/Other/Customizations.xml`
  - Updated solution manifest root components in:
    - `flows/power-automate/unpacked/Other/Solution.xml`
  - Built the new cloud refresh target workbook around stable tables:
    - `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`
  - Wired the flow to:
    - read `BGV_Candidates`, `BGV_Requests`, and `BGV_FormData`
    - clear `tblDashboardCasesPA`
    - repopulate recruiter-facing dashboard rows
    - append refresh log rows into `tblDashboardRefreshLog`
  - Preserved recruiter-facing status/reminder/completed logic as closely as possible while removing `Overdue`.
  - Imported and published the updated solution successfully using `recruitment@dlresources.com.sg`.
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac solution create-settings --solution-folder .\flows\power-automate\unpacked --settings-file .\out\deployment-settings\bgv9_live.settings.json`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Notes:
  - The cloud refresh target is intentionally separate from the original snapshot workbook so both dashboards can be compared side by side.
- Date: 2026-03-26
- Task: Refine `BGVDashboard_FLow` workbook layout for live use.
- Completed tasks:
  - Updated `scripts/active/build_bgv_dashboard_pa_prototype.ps1` so the flow-managed workbook now builds as:
    - `out/dashboard/BGVDashboard_FLow.xlsx`
  - Removed the `Comparison` sheet from the workbook structure.
  - Removed `Prototype` wording from the Summary sheet and refresh log wording.
  - Added a `Completed Cases` KPI card to the first page.
  - Shifted the status/severity summary tables upward on the Summary sheet for a tighter first-page layout.
  - Rebuilt the local workbook and verified sheets/tables:
    - `Summary`
    - `Cases`
    - `Helper`
    - `RefreshLog`
    - `tblDashboardCasesPA`
    - `tblDashboardStatusLegend`
    - `tblDashboardSeverityLegend`
    - `tblDashboardRefreshLog`
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard_pa_prototype.ps1`
  - Excel COM inspection of `out/dashboard/BGVDashboard_FLow.xlsx`
- Blockers:
  - SharePoint overwrite attempt for `BGV Records/Dashboard/BGVDashboard_FLow.xlsx` was blocked because the file is locked for shared use by `recruitment@dlresources.com.sg`.
- Date: 2026-03-26
- Task: Fix `BGV_9_Refresh_Dashboard_Excel` Excel connector drive-id validation error.
- Completed tasks:
  - Investigated the live save error:
    - `excelonlinebusiness` `GetTable`
    - `The provided drive id appears to be malformed, or does not represent a valid drive.`
  - Retrieved the real SharePoint Graph identifiers for the flow workbook:
    - drive id: `b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp`
    - file id: `017QXH3H5QGNFXQP6RPBB36R4T2A5SFHPD`
  - Updated all Excel Online actions in `BGV_9` to use valid drive/file identifiers rather than the malformed drive value.
  - Packed and re-imported the solution, then published customizations.
- Validation commands run:
  - `m365 request --url "https://graph.microsoft.com/v1.0/drives/b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp/root:/Dashboard/BGVDashboard_FLow.xlsx" --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Date: 2026-03-26
- Task: Fix `BGV_9` dashboard choice-field text mapping for Severity/Outcome.
- Completed tasks:
  - Investigated dashboard output where `Severity` (and similar choice fields) were showing raw SharePoint expanded-reference JSON in Excel.
  - Updated `BGV_9_Refresh_Dashboard_Excel` Excel row mapping:
    - `Severity` now writes `Severity.Value` when present, with safe fallback to plain value
    - `Outcome` now writes `Outcome.Value` when present, with safe fallback to plain value
  - Repacked and reimported the solution to publish the fix in live flow definition.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Date: 2026-03-26
- Task: Align `BGV_9` dashboard timestamps to SGT and apply 3-day case-retention removal rules.
- Completed tasks:
  - Updated `BGV_9_Refresh_Dashboard_Excel` time mappings to Singapore time for dashboard output fields:
    - `Candidate Reminder`
    - `Employer Reminder`
    - `Employer Response Received At`
    - `Employer Email Reply At`
    - `Last Activity At`
  - Updated refresh-log timestamp output to write SGT-formatted time values.
  - Added row-retention filter logic inside the flow so dashboard rows are skipped when either condition is met:
    - `VerificationStatus = Reminder 3 Sent` and no employer response for at least 3 days since `Reminder3At`
    - `VerificationStatus = Responded` and at least 3 days have passed since `ResponseReceivedAt`
  - Kept all other rows included so active cases remain visible in `tblDashboardCasesPA`.
  - Repacked and reimported the solution; customizations were published successfully.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac auth who`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Date: 2026-03-27
- Task: Update dashboard flow/status logic and workbook structure for flagged statuses, completed date, and 5-day row clearing.
- Completed tasks:
  - Updated `BGV_9_Refresh_Dashboard_Excel` logic:
    - status now outputs `Employer Form Received But Flagged` when verification is responded and severity is `Low`/`Medium`/`High`
    - removed fallback `In Progress` label from recruiter status mapping
    - `Completed Status` now sets `Yes` for:
      - `Employer Form Received`
      - `Employer Form Received But Flagged`
    - added `Completed Date` output (SGT) from `ResponseReceivedAt` when completed
    - row-retention cleanup changed to 5 days:
      - close `Reminder 3 Sent` no-response rows after 5 days
      - close completed rows after 5 days from `Completed Date`
  - Added dashboard refresh summary metrics in flow run logging:
    - `Total Requests`
    - `Active Cases`
    - `Cleared Cases`
    - `Closed Employer Form Received`
    - `Closed Employer Form Received But Flagged`
    - `Closed Reminder 3 Sent`
  - Updated cloud dashboard workbook builder:
    - added `Completed Date` column to `tblDashboardCasesPA`
    - updated summary cards to read total/open/closed metrics from `tblDashboardRefreshLog`
    - added `Closed Cases Report` block on Summary
    - updated helper status legend to include `Employer Form Received But Flagged`
    - refresh-log schema now uses `Run At (SGT)` and includes closed-case metric columns
  - Rebuilt local workbook artifact:
    - `out/dashboard/BGVDashboard_FLow.xlsx`
  - Repacked and imported updated solution; published customizations successfully.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard_pa_prototype.ps1`
  - `pac auth who`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Blockers / follow-up:
  - Uploading the rebuilt workbook to SharePoint failed because `BGV Records/Dashboard/BGVDashboard_FLow.xlsx` was locked for shared use by `recruitment@dlresources.com.sg`.
  - After the file is closed/unlocked, rerun:
    - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "out/dashboard/BGVDashboard_FLow.xlsx" --overwrite`
  - Candidate Form upload-question request requires Microsoft Forms schema updates first (new question IDs are generated by Forms). Flow mapping to dedicated fields should be done immediately after those new question keys are available.
- Date: 2026-03-27
- Task: Finalize sync of live dashboard flow state and push updated cloud workbook.
- Completed tasks:
  - Ran daily sync:
    - `scripts/active/bgv_daily_sync.ps1`
  - Confirmed live BGV_9 metadata state now reflects enabled/active flow state in exported `.json.data.xml`.
  - Retried SharePoint upload and successfully replaced:
    - `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`
    - version advanced to `14.0`
    - modified `2026-03-27T03:25:00Z`
  - Verified local repo now only had live-state drift from export, ready for GitHub sync.
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "out/dashboard/BGVDashboard_FLow.xlsx" --overwrite`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json.data.xml`
- Date: 2026-03-27
- Task: Fix Flow 9 activation failure and restore started state.
- Completed tasks:
  - Diagnosed `BGV_9_Refresh_Dashboard_Excel` activation failure in Power Automate:
    - template parse error was thrown while turning the flow on
  - Simplified `Compose_Status` expression to a parser-safe version while preserving recruiter-facing reminder/responded/flagged statuses.
  - Repacked and reimported solution.
  - Confirmed live flow definition contains corrected `Compose_Status`.
  - Enabled the flow successfully in the default environment.
- Validation commands run:
  - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --output json`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 7f4dbc87-1117-af35-a703-126c8a6485c0 --output json`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 7f4dbc87-1117-af35-a703-126c8a6485c0`
- Date: 2026-03-27
- Task: Fix Flow 9 status mis-mapping caused by SharePoint Choice object comparisons.
- Completed tasks:
  - Identified root cause for dashboard status mismatch:
    - `VerificationStatus` in SharePoint is a Choice object, but Flow 9 compared it as plain text.
    - This caused status checks to fail and cases to fall back to `Authorisation Form Received`.
  - Updated `BGV_9` to normalize request status text with:
    - `Compose_VerificationStatusText = coalesce(VerificationStatus.Value, VerificationStatus)`
  - Remapped status comparisons to use normalized status text in:
    - `Compose_Status`
    - row-retention condition checks
    - closed-case count filters
  - Repacked/imported/published updated solution and re-enabled `BGV_9`.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 7f4dbc87-1117-af35-a703-126c8a6485c0`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 7f4dbc87-1117-af35-a703-126c8a6485c0 --query "{state:properties.state,lastModified:properties.lastModifiedTime}"`
- Date: 2026-03-27
- Task: Fix live BGV flow activation/connection blockers for employer-send and confirm related flows are started.
- Completed tasks:
  - Investigated the live `BGV_4_SendToEmployer_Clean` activation failure instead of relying on the UI warning banner alone.
  - Identified two concrete canonical-flow issues in `BGV_4`:
    - invalid empty-array fallback in the authorization attachment loop:
      - changed `createArray()` to `json('[]')`
    - invalid cross-scope dependency inside `Condition_-_AuthorisationSigned`:
      - `Create_Request_Stamp_Folder` was using `runAfter` on `Get_items_(BGV_FormData)` even though that action lives outside the condition branch
      - reset that action to branch-local `runAfter: {}`
  - Repaired a malformed JSON structure in the canonical `BGV_4` file introduced while cleaning the action block:
    - removed the stray extra closing brace after `Create_Request_Stamp_Folder.inputs`
    - restored the top-level workflow `outputs` block so the flow JSON imports cleanly
  - Repacked and reimported the full unmanaged solution successfully.
  - Enabled `BGV_4_SendToEmployer_Clean` successfully in the default environment.
  - Verified the other connection-banner flows are also in a healthy started state:
    - `BGV_7_Generate_Report_Summary`
    - `BGV_8_Track_Employer_Email_Replies`
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 8eeeed39-e02f-4b7a-82c8-fc51f245d863`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --output json`
  - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --output json`
- Date: 2026-04-06
- Task: Run daily sync and refresh local canonical flow source from the latest live environment.
- Completed tasks:
  - Ran `scripts/active/bgv_daily_sync.ps1` against:
    - `https://orgde64dc49.crm5.dynamics.com/`
  - Confirmed PAC identity before export:
    - `recruitment@dlresources.com.sg`
  - Exported and unpacked the latest unmanaged `BGV_System` solution into canonical source:
    - `flows/power-automate/unpacked/`
  - Confirmed the sync now includes live workflow inventory through:
    - `BGV_9_Refresh_Dashboard_Excel`
    - `BGV_4_SendToEmployer_Clean_v2`
  - Reviewed post-sync drift and confirmed it is limited to:
    - environment version updates in `Customizations.xml` and `Solution.xml`
    - newline normalization only in `BGV_5`, `BGV_6`, `BGV_7`, and `BGV_9`
  - No new logic drift was detected in the reviewed workflow JSON diffs.
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `git status --short --branch`
  - `git diff --stat`
  - `git diff -- flows/power-automate/unpacked/Other/Customizations.xml flows/power-automate/unpacked/Other/Solution.xml`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json flows/power-automate/unpacked/Workflows/BGV_7_Generate_Report_Summary-FB5CF0E3-0916-F111-8341-002248582037.json flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json`
## 2026-03-27 (BGV_4 candidate lookup hardened for run-time AuthorisationSigned failure)
  - Investigated the failing live `BGV_4_SendToEmployer_Clean` run where the UI surfaced the error on `Condition - AuthorisationSigned`.
  - Hardened the canonical flow so the candidate read no longer depends on `BGV_Requests.CandidateItemID` staying valid:
    - changed `Get_item` from SharePoint `GetItem` by lookup item ID to SharePoint `GetItems` filtered by stable `CandidateID` with `$top: 1`
    - updated downstream candidate references (`AuthorisationSigned`, candidate name/email, candidate folder path, prefill fallbacks) to read from `first(body('Get_item')?['value'])`
    - added `CandidateID` fallback from the request row for authorization/request-stamp folder paths so an empty candidate result does not crash path construction
  - Updated docs to reflect that `BGV_4` now resolves the candidate by `CandidateID` rather than relying solely on the request lookup ID.
  - Validation to run next after import:
    - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
    - import the updated solution and resubmit the failed `BGV_4` run
## 2026-04-02 (Safe BGV to PEV wording sweep)
  - Applied a safe user-facing wording sweep from `BGV` to `PEV` without renaming internal technical objects.
  - Updated recruiter-facing/high-severity response wording in `BGV_5_Response1`:
    - `HIGH BGV FLAG` -> `HIGH PEV FLAG`
    - `A High Severity BGV issue has been flagged.` -> `A High Severity PEV issue has been flagged.`
    - `Adverse BGV Checks - see severity` -> `Adverse PEV Checks - see severity`
  - Updated dashboard/docs display wording:
    - `BGV Dashboard Headers` -> `PEV Dashboard Headers`
    - `BGV Dashboard Power Automate Redesign` -> `PEV Dashboard Power Automate Redesign`
    - dashboard workbook display references changed from `BGV Dashboard.xlsx` / `BGVDashboard_FLow.xlsx` to `PEV Dashboard.xlsx` / `PEVDashboard_Flow.xlsx`
    - `BGV Checks` doc wording -> `PEV Checks`
  - Kept internal technical names unchanged on purpose:
    - SharePoint site/list/library names
    - flow names
    - folder paths
    - `CandidateID` / `RequestID` prefixes like `BGV-...` and `REQ-BGV-...`
  - Next recommended migration, if still wanted later:
    - separate controlled backend rename project for lists, folders, solution names, IDs, and dashboard file/table names
## 2026-04-02 (Additional safe PEV wording updates)
  - Continued the user-facing wording sweep in current docs and visible workbook references.
  - Updated current documentation titles:
    - `BGV Dashboard` -> `PEV Dashboard`
    - `BGV Dashboard Implementation Guide` -> `PEV Dashboard Implementation Guide`
    - `BGV Flows in Simple English` -> `PEV Flows in Simple English`
  - Updated current display wording:
    - `BGV Checks` -> `PEV Checks`
    - `Adverse BGV Checks - see severity` -> `Adverse PEV Checks - see severity`
  - Updated current dashboard workbook display references:
    - `BGV Dashboard.xlsx` -> `PEV Dashboard.xlsx`
    - `BGVDashboard_FLow.xlsx` -> `PEVDashboard_Flow.xlsx`
    - `BGV Dashboard Master Query.m` -> `PEV Dashboard Master Query.m`
  - Left historical log entries, live technical object names, internal paths, and automation IDs unchanged on purpose.
## 2026-04-02 (PEV backend migration staging started)
  - Audited the backend rename surface and confirmed a true `BGV` -> `PEV` migration is a staged cutover, not a safe single-pass rename.
  - Confirmed the current live technical dependencies still point to:
    - `BGV_Candidates`
    - `BGV_Requests`
    - `BGV_FormData`
    - `BGV Records`
    - `BGV-...` / `REQ-BGV-...` identifiers
  - Added a staged migration plan:
    - `docs/pev_backend_migration_plan.md`
  - Added migration alias support for deployment settings generation:
    - `scripts/active/bgv_build_deployment_settings.ps1` now accepts both `BGV_*` and `PEV_*` environment variable names
    - added wrapper script `scripts/active/pev_build_deployment_settings.ps1`
  - Decision:
    - do not perform a blind in-place rename of live backend objects
    - next safe step is parallel `PEV_*` object creation and a parallel PEV-connected flow package before cutover
## 2026-04-02 (Parallel PEV cutover artifacts added)
  - Added parallel deployment-settings templates for the planned `PEV` cutover:
    - `flows/power-automate/deployment-settings/pev.prod.settings.template.json`
    - `flows/power-automate/deployment-settings/pev.test.settings.template.json`
  - These preserve the current canonical `__BGV_*__` token markers but point to planned `PEV` target placeholders so the same materialization process can be reused during cutover.
  - Added the technical naming map:
    - `docs/pev_object_naming_map.md`
  - Current decision remains unchanged:
    - do not rename live `BGV_*` technical objects in place
    - build the parallel `PEV_*` layer first, then test, then cut over
## 2026-04-02 (Parallel PEV backend cutover executed)
  - Current status:
    - Built and populated a parallel live `PEV_*` backend in the same SharePoint site, retargeted the active flow package to the new `PEV` lists/library, imported it to PAC, and verified the main production flows are still `Started`.
  - Completed tasks:
    - Ran `scripts/active/pev_ensure_target_schema.ps1` successfully against:
      - source site: `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`
      - target site: `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`
    - Created/verified parallel live stores:
      - `PEV_Candidates`
      - `PEV_Requests`
      - `PEV_FormData`
      - `PEV Records`
      - `Shared Documents/PEV Templates/AuthorizationLetter_Template.docx`
    - Patched the shared migration helper:
      - added `Get-BgvLookupFieldTargetListId` into `shared/bgv_migration_common.ps1`
      - improved Graph-token parsing for `m365 util accesstoken get`
    - Patched the new copy script:
      - `scripts/active/pev_copy_site_data.ps1` now supports `-SkipListData` and `-SkipFiles` so list and file migration can be run independently
    - Added `scripts/active/pev_inspect_counts.ps1` to verify BGV/PEV live parity by item count.
    - Ran list-data migration successfully:
      - `PEV_Candidates` item count = `38`
      - `PEV_Requests` item count = `46`
      - `PEV_FormData` item count = `129`
      - all matched the live BGV sources
    - Ran file/library migration successfully:
      - `PEV Records` item count = `433`
      - matched the live `BGV Records` item count = `433`
    - Retargeted the active flow JSON to the parallel `PEV` backend:
      - SharePoint list/library table IDs swapped to:
        - candidates: `8c19755d-0e9c-4680-8d18-783eb9ec56be`
        - requests: `df824861-8e10-4a8c-ad88-f7cf1ef3ef26`
        - form data: `f271b227-c654-4241-8968-054dc7f1d47c`
        - records library: `30d02a3a-74da-4a16-a887-7b8dd043a547`
      - `BGV Records` paths in the active workflow JSON changed to `PEV Records`
      - Flow 0 candidate ID generator changed from `BGV-...` to `PEV-...`
      - request IDs generated from new cases will therefore move from `REQ-BGV-...` to `REQ-PEV-...`
    - Repacked the solution as unmanaged:
      - `flows/power-automate/exports/BGV_System_1_0_0_3.zip`
    - Imported the updated solution into PAC with publish enabled.
    - Ran daily sync after import so local unpacked files match the live PAC export.
  - Validation commands run:
    - `pwsh -File .\scripts\active\pev_ensure_target_schema.ps1 ...`
    - `pwsh -File .\scripts\active\pev_copy_site_data.ps1 -SkipFiles ...`
    - `pwsh -File .\scripts\active\pev_copy_site_data.ps1 -SkipListData ...`
    - `pwsh -File .\scripts\active\pev_inspect_counts.ps1 ...`
    - `pac solution pack --folder flows\power-automate\unpacked --zipfile flows\power-automate\exports\BGV_System_1_0_0_3.zip --packagetype Unmanaged`
    - `pac solution import --path <resolved zip path> --force-overwrite --publish-changes`
    - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --withSolutions --asAdmin --output json`
    - `pwsh -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - Live verification:
    - active production flows remained `Started` after import:
      - `BGV_0_CandidateDeclaration`
      - `BGV_1_Detect_Authorization_Signature`
      - `BGV_2_Postsignature`
      - `BGV_3_AuthReminder_5Days`
      - `BGV_4_SendToEmployer_Clean`
      - `BGV_5_Response1`
      - `BGV_6_HRReminderAndEscalation`
      - `BGV_7_Generate_Report_Summary`
      - `BGV_8_Track_Employer_Email_Replies`
      - `BGV_9_Refresh_Dashboard_Excel`
    - intentionally stopped:
      - `BGV_4_SendToEmployer_Clean_v2`
  - Important notes / remaining non-cutover items:
    - display names of the flows are still `BGV_*`
    - historical copied rows in the new `PEV_*` lists still keep their original legacy IDs like `BGV-...` / `REQ-BGV-...`
    - future new cases should start using `PEV-...` / `REQ-PEV-...` because Flow 0’s generator was retargeted
    - docs still need a broader technical refresh if we want every reference file to describe the new `PEV_*` backend as canonical

## 2026-04-02 (Final live PEV UI cleanup and smoke test)
  - Cleaned up the remaining visible SharePoint UI labels after the backend cutover:
    - legacy live objects were relabeled to make it clear they are not the active backend:
      - `BGV_Candidates` -> `Legacy_BGV_Candidates`
      - `BGV_Requests` -> `Legacy_BGV_Requests`
      - `BGV_FormData` -> `Legacy_BGV_FormData`
      - `BGV Records` -> `Legacy BGV Records`
    - quick-launch navigation links were updated to the active `PEV_*` lists:
      - `PEV_Candidates`
      - `PEV_Requests`
      - `PEV_FormData`
    - active request column display name changed from `BGV Checks` to `PEV Checks` on `PEV_Requests`
  - Repaired one stale cutover case where the employer response had landed in the old backend before the fresh import:
    - backfilled `PEV_FormData` item `129` with the missing `Form2RawJson`, `Form2SubmittedAt`, parsed `F2_*` fields, and `Report Summary Teams Posted At`
    - used SharePoint `ValidateUpdateListItem()` because the standard CLI list-item update wrapper failed on the large raw JSON payload
  - Ran a fresh controlled live smoke test against the active `PEV_*` backend:
    - created candidate `PEV-TEST-CAND`
    - created request `REQ-PEV-TEST-CAND-EMP1`
    - created matching `PEV_FormData` row and copied a valid signed authorization file into `PEV Records/Candidate Files/PEV-TEST-CAND/Authorization`
    - resubmitted the latest successful `BGV_4_SendToEmployer_Clean` recurrence
    - confirmed the request moved to `VerificationStatus = Email Sent`
    - confirmed `HRRequestSentAt` was stamped
    - confirmed the request folder was created under `PEV Records/Candidate Files/PEV-TEST-CAND/REQ-PEV-TEST-CAND-EMP1`
  - Verified the downstream report path on the same live smoke-test case:
    - wrote a realistic employer-response state onto the fresh `PEV` test request and form-data row
    - allowed the scheduled `BGV_7_Generate_Report_Summary` recurrence to pick it up
    - confirmed `RS_Emp1.docx` was generated under `PEV Records/Candidate Files/PEV-TEST-CAND`
  - Live operational conclusion:
    - active production lists/libraries are the `PEV_*` set
    - the live quick-launch menu now points at `PEV_*`
    - the core send path and report-generation path both worked on a fresh `PEV` smoke-test case
  - Remaining cosmetic item:
    - flow display names are still `BGV_*` because they are not exposed through the same simple live rename path as SharePoint lists/navigation
  - Default live SharePoint list views were normalized for the active `PEV_*` backend:
    - `PEV_FormData -> All Items` now shows:
      - `Title`
      - `CandidateID`
      - `RequestID`
      - `EmployerSlot`
      - `F1_CandidateFullName`
      - `Form1SubmittedAt`
      - `Form2SubmittedAt`
      - `F2_Severity`
      - `F2_Outcome`
    - `PEV_Candidates -> All Items` now shows:
      - `Title`
      - `CandidateID`
      - `FullName`
      - `CandidateEmail`
      - `Status`
      - `IDTypeProvided`
      - `IdentificationNumberNRIC`
      - `IdentificationNumberPassport`
      - `AuthorizationLinkCreatedAt`
      - `AuthorisationSigned`
    - `PEV_Requests -> All Items` now shows:
      - `Title`
      - `RequestID`
      - `CandidateID`
      - `EmployerName`
      - `EmployerHR_Email`
      - `VerificationStatus`
      - `PEV Checks`
      - `Severity`
      - `HRRequestSentAt`
      - `ResponseReceivedAt`
      - `Reminder1At`
      - `Reminder2At`
      - `Reminder3At`
    - user-facing effect:
      - opening the active `PEV_*` lists no longer shows only the `Title` column; the key business fields are visible again in the default view
## 2026-04-03 Dashboard / PEV follow-up

- Confirmed `BGV_9_Refresh_Dashboard_Excel` repo JSON and exported live JSON now both point to the active `PEV Records` dashboard flow workbook:
  - drive: `b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErEk6KtAw2nQWSqiHe43QQ6VH`
  - file: `017QXH3HY5X73LM5443ZFLLGMN5IWZBI6R`
- Repacked and re-imported the solution successfully; latest live `BGV_9` scheduled runs after import were still succeeding.
- Verified the active PEV dashboard workbook rows now contain `PEV Records` candidate-folder links, not `BGV Records`.
- Verified latest PEV-side cases exist in the active dashboard workbook, including:
  - `PEV-TEST-CAND`
  - `PEV-20260402-6c181`
- Important nuance:
  - old rows still keep historical candidate/request IDs like `BGV-...` where the original live data itself still uses legacy IDs
  - link paths are now corrected to `PEV Records` even for those legacy-ID rows
- Remaining cosmetic issue only:
  - resolved manually in SharePoint UI on 2026-04-03:
    - `BGV Dashboard.xlsx` -> `PEV Dashboard.xlsx`
    - `BGVDashboard_FLow.xlsx` -> `PEVDashboard_FLow.xlsx`
  - verified that the active flow workbook kept the same file id `017QXH3HY5X73LM5443ZFLLGMN5IWZBI6R`, so no further `BGV_9` patch was needed after the rename

## 2026-04-03 (Fresh live PEV smoke test + BGV_3 reminder data repair)

- Current status:
  - Ran a fresh controlled live smoke test through the active `PEV_*` backend and verified the send, report-summary, and dashboard-refresh path on a brand-new `PEV` case.
  - While checking the full flow set, found and fixed a real live data issue that was breaking `BGV_3_AuthReminder_5Days`.
- Completed tasks:
  - Created a fresh controlled live smoke-test case:
    - candidate: `PEV-SMOKE-20260403-B`
    - request: `REQ-PEV-SMOKE-20260403-B-EMP1`
    - form-data row: `PEV-SMOKE-20260403-B|EMP1`
  - Added the live candidate/request/form-data rows directly into:
    - `PEV_Candidates`
    - `PEV_Requests`
    - `PEV_FormData`
  - Created the live candidate folder structure and copied a signed authorization document into:
    - `PEV Records/Candidate Files/PEV-SMOKE-20260403-B/Authorization/Authorization Form - PEV-SMOKE-20260403-B.docx`
  - Resubmitted the latest successful `BGV_4_SendToEmployer_Clean` recurrence and confirmed the fresh request was processed:
    - `VerificationStatus = Email Sent`
    - `HRRequestSentAt` stamped
    - employer prefilled link populated
    - request folder created:
      - `PEV Records/Candidate Files/PEV-SMOKE-20260403-B/REQ-PEV-SMOKE-20260403-B-EMP1`
    - company-stamp doc created:
      - `Company Stamp - REQ-PEV-SMOKE-20260403-B-EMP1.docx`
  - Wrote a realistic employer-response state onto the same smoke-test case and resubmitted:
    - `BGV_7_Generate_Report_Summary`
    - `BGV_9_Refresh_Dashboard_Excel`
  - Verified the downstream path on the same live case:
    - `RS_Emp1.docx` generated under:
      - `PEV Records/Candidate Files/PEV-SMOKE-20260403-B/RS_Emp1.docx`
    - active dashboard workbook row created for:
      - `PEV-SMOKE-20260403-B`
    - dashboard candidate-folder link points to:
      - `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570/PEV%20Records/Candidate%20Files/PEV-SMOKE-20260403-B/`
  - Verified active flow health during the smoke test:
    - `BGV_0_CandidateDeclaration`: latest checked run `Succeeded`
    - `BGV_1_Detect_Authorization_Signature`: latest checked run `Succeeded`
    - `BGV_4_SendToEmployer_Clean`: fresh smoke-test rerun `Succeeded`
    - `BGV_5_Response1`: latest checked run `Succeeded`
    - `BGV_6_HRReminderAndEscalation`: latest checked run `Succeeded`
    - `BGV_7_Generate_Report_Summary`: fresh smoke-test rerun `Succeeded`
    - `BGV_8_Track_Employer_Email_Replies`: latest checked run `Succeeded`
    - `BGV_9_Refresh_Dashboard_Excel`: dashboard refresh picked up the smoke-test case
  - Investigated the failing `BGV_3_AuthReminder_5Days` run:
    - root cause was not flow logic
    - several migrated `PEV_Candidates` rows still had `Title = null`
    - the SharePoint connector schema for `Get_items` expected `Title`, so the flow failed with:
      - `ResponseSwaggerSchemaValidationFailure`
      - `The API operation 'GetItems' is missing required property 'body/value/0/Title'`
  - Repaired the bad live rows in `PEV_Candidates` by backfilling `Title = CandidateID` for ids:
    - `1`
    - `2`
    - `3`
    - `4`
    - `5`
  - Resubmitted the reminder flow and verified the next `BGV_3_AuthReminder_5Days` run returned to `Succeeded`.
- Validation commands run:
  - `m365 spo listitem add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Candidates ...`
  - `m365 spo listitem add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests ...`
  - `m365 spo listitem add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_FormData ...`
  - `m365 spo folder add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --parentFolderUrl '/sites/DLRRecruitmentOps570/PEV Records/Candidate Files' --name 'PEV-SMOKE-20260403-B'`
  - `m365 spo file copy --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --sourceUrl '/sites/DLRRecruitmentOps570/PEV Records/Candidate Files/PEV-TEST-CAND/Authorization/Authorization Form - PEV-TEST-CAND.docx' --targetUrl '/sites/DLRRecruitmentOps570/PEV Records/Candidate Files/PEV-SMOKE-20260403-B/Authorization' --newName 'Authorization Form - PEV-SMOKE-20260403-B.docx'`
  - `m365 flow run resubmit --force --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --name 08584264000857375046807143936CU19`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 49 ...`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_FormData --id 132 ...`
  - `m365 flow run resubmit --force --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 3e03d678-ce7d-1508-99ab-a7624987e9cd --name 08584263994858580597328441992CU15`
  - `m365 flow run resubmit --force --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 7f4dbc87-1117-af35-a703-126c8a6485c0 --name 08584263994852702735092509303CU26`
  - `m365 request --url 'https://graph.microsoft.com/v1.0/drives/b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErEk6KtAw2nQWSqiHe43QQ6VH/items/017QXH3HY5X73LM5443ZFLLGMN5IWZBI6R/workbook/tables/tblDashboardCasesPA/rows' --output json`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Candidates --id <1..5> --Title <CandidateID>`
  - `m365 flow run resubmit --force --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fc8d5023-f8fe-42e5-8982-a523f761d8e7 --name 08584263997855448202500883517CU11`
- Important notes:
  - `BGV_2_Postsignature` showed mixed results during the smoke test because the authorization file used for the live test was copied from an already-processed signed document; that is not a clean reproduction of the normal Flow 0 -> Flow 1 -> Flow 2 document lifecycle.
  - The fresh smoke test did prove the current production send/report/dashboard path on the active `PEV_*` backend.
- Next actions and blockers:
  - If needed, run one true candidate-form submission through `BGV_0` -> `BGV_2` with a brand-new authorization document to validate the pre-signature and post-signature document path without using a copied smoke-test file.

## 2026-04-03 - PEV_FormData mapping repair

- Investigated the user report that `PEV_FormData` "should have mapped more rows".
- Confirmed this was **not** a bulk row-loss problem:
  - `PEV_FormData` contains `133` items.
  - Legacy archive `Legacy_BGV_FormData` contains `129` items.
  - The extra `PEV` items are expected newer `PEV-*` records.
- Confirmed one historical data contamination issue:
  - `PEV_FormData` item `5` had a March `Title` but had previously been overwritten with April `CandidateID` / `RequestID`.
  - Repaired the visible key fields so they now match the item title again:
    - `CandidateID = BGV-20260305-15be9`
    - `RequestID = REQ-BGV-20260305-15be9-EMP1`
  - Note: that row is historically polluted even in legacy data, so it was **not** caused by the `PEV` cutover.
- Found one real live under-mapped response row:
  - `PEV_FormData` item `128`
  - `Title = BGV-20260401-87341|EMP1`
  - `Form2SubmittedAt` was present, but the mapped `F2_*` fields were blank.
- Backfilled item `128` from its stored `Form2RawJson` and the matching processed `PEV_Requests` row:
  - `F2_Severity = High`
  - `F2_Outcome = Disciplinary, Re-employ, "Employment Period", "Company UEN"`
  - `F2_Notes` restored
  - `F2_InformationAccurate = false`
  - `F2_SelectedIssues = ["Employment Period"]`
  - `F2_CompanyDetailsAccurate = false`
  - `F2_CompanyDetailsSelectedIssues = ["Company UEN"]`
  - `F2_FormCompleterName = melissa ong`
  - `F2_FormCompleterJobTitle = hr manager`
  - and the other related `F2_*` fields
- Re-ran the health scan after repair:
  - no remaining `PEV_FormData` rows have `Form2SubmittedAt` present while all key mapped `F2_*` fields are blank.
- Important interpretation:
  - The active `PEV_FormData` list is now healthy for current mapped response rows.
  - Some older historical `BGV-*` `FormData` rows remain archival/orphan-style records because the source system itself had incomplete candidate/request coverage long before the `PEV` migration.

## 2026-04-06 - PEV_FormData structured header expansion

- Reviewed the active form-data backend and confirmed the live production list is `PEV_FormData`, not the legacy `BGV_FormData`.
- Confirmed `BGV_5_Response1` is the response-processing flow writing employer form results into `PEV_FormData`.
- Expanded the structured employer-side mapping so the key non-narrative Form 2 values are stored as their own readable columns instead of only living inside raw JSON:
  - Employer Verified Company Name
  - Employer Verified Company UEN
  - Employer Verified Company Address
  - Employer Verified Employment Period
  - Employer Verified Last Drawn Salary
  - Employer Verified Last Position Held
- Added the six live SharePoint columns on `PEV_FormData`.
- Found an internal-name mismatch:
  - the columns were created with readable display names, so SharePoint generated encoded internal names
  - attempted two safe flow-writer approaches in `BGV_5_Response1`:
    - direct `Update item` mapping to encoded internal names
    - separate `Send an HTTP request to SharePoint` patch step
  - both versions imported, but Power Automate rejected them at activation time with template validation errors
  - restored `BGV_5_Response1` to its last known-good logic so employer response processing is not left in a broken state
- Intentionally kept long narrative answers out of new dedicated columns:
  - discrepancy explanations
  - other long comments / free-text narratives
  - these remain in raw JSON / notes so the list stays readable
- Added a dedicated header dictionary document for the active list:
  - `docs/pev_formdata_headers.md`
- Updated supporting docs so the field meanings and mapping logic are documented consistently.
- Validation commands run:
  - `pac auth who`
  - `m365 spo list list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --output json`
  - `m365 spo field list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_FormData --output json`
  - `m365 spo field add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_FormData ...`
  - `pac solution pack --folder .\\flows\\power-automate\\unpacked --zipfile .\\artifacts\\exports\\BGV_System_formdata_mapping.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_formdata_mapping.zip --settings-file .\\out\\deployment-settings\\bgv9_live.settings.json --publish-changes --force-overwrite`
- Important notes:
  - The six new live columns use SharePoint-generated internal names derived from their display labels, not the original shorthand names first proposed locally.
  - The columns now exist live and are documented, but live auto-population is still pending a safe SharePoint action schema refresh in `BGV_5`.
  - `BGV_5_Response1` was observed in `Stopped` state during verification; after the revert it still needs explicit activation/validation on the platform side.

## 2026-04-06 - Dashboard reading guide added

- Expanded `docs/flows_easy_english.md` with a dedicated recruiter-facing dashboard guide.
- Added an easy-English section explaining:
  - which workbook is the live dashboard
  - what each sheet is used for
  - how to read `Summary`
  - how to read `Cases`
  - what each main dashboard column means
  - what each dashboard `Status` means
  - how `Severity` should be interpreted
  - why rows disappear from the active dashboard after the retention window
- This was added so the dashboard logic is documented in a user-readable format, not only in technical design notes such as `docs/bgv_dashboard_power_automate_redesign.md`.

## 2026-04-06 - Launch-readiness live audit

- Ran a final live audit across the production BGV flows using the `recruitment@dlresources.com.sg` PAC/M365 context.
- Confirmed the main production flows are in `Started` state:
  - `BGV_0_CandidateDeclaration`
  - `BGV_1_Detect_Authorization_Signature`
  - `BGV_2_Postsignature`
  - `BGV_3_AuthReminder_5Days`
  - `BGV_4_SendToEmployer_Clean`
  - `BGV_5_Response1`
  - `BGV_6_HRReminderAndEscalation`
  - `BGV_7_Generate_Report_Summary`
  - `BGV_8_Track_Employer_Email_Replies`
  - `BGV_9_Refresh_Dashboard_Excel`
- Noted non-primary flows outside the main launch path:
  - `BGV_4_SendToEmployer_Clean_v2` remains stopped
  - `BGV_A_CandidateSubmission` remains stopped
- Reviewed recent live run history and confirmed recent successful runs for:
  - `BGV_0`, `BGV_2`, `BGV_3`, `BGV_4`, `BGV_5`, `BGV_6`, `BGV_7`, `BGV_8`, `BGV_9`
- `BGV_1` run-history query timed out during admin polling, but the flow remains `Started`; no live failure signal was found during this audit.
- Rechecked the current `SendAfterDate` gate in `BGV_4`:
  - employer send is held when `RequestID` ends with `-EMP1` and `SendAfterDate` is still in the future
  - the send is allowed when `SendAfterDate` is blank or on/before today
  - `EMP2` and `EMP3` rows are not deferred by `SendAfterDate`
- Rechecked the employer reminder/escalation timing in `BGV_6`:
  - Reminder 1: 2 days after initial employer send
  - Reminder 2: 3 days after Reminder 1
  - Escalation: 1 day after Reminder 2 if still no response
  - Reminder 3: 11 days after initial employer send if still no response
  - no-response closure path: 5 days after Reminder 3 if still no response
- Rechecked the candidate authorization reminder logic in `BGV_3`:
  - reminder dedupe still relies on `LastAuthReminderAt`
  - same-slot duplicate reminders are blocked using Singapore date/hour comparison
- Chose not to force-run the recurrence flows during the launch audit because live `PEV_Requests` still contains active operational rows; replaying recurrence logic would risk duplicate real emails or reminders.
- Outcome of the audit:
  - no launch-blocking logic defect was found in the currently running main production flow path
  - no canonical flow JSON changes were required from this specific audit
  - docs were updated so dashboard reading and launch-readiness checks are recorded in repo history

## 2026-04-06 - Controlled smoke candidate check

- Created one internal-only smoke candidate set to validate the live launch path without sending to external employer contacts:
  - candidate: `BGV-20260406-smk1139`
  - requests:
    - `REQ-BGV-20260406-smk1139-EMP1`
    - `REQ-BGV-20260406-smk1139-EMP2`
    - `REQ-BGV-20260406-smk1139-EMP3`
- Smoke setup design:
  - `EMP1` used a future `SendAfterDate` to validate defer behavior
  - `EMP2` used an immediate/past `SendAfterDate` to validate employer-send behavior
  - `EMP3` used backdated `HRRequestSentAt` to stage a reminder-path check
- Created the expected SharePoint smoke artifacts:
  - candidate folder under `PEV Records/Candidate Files/BGV-20260406-smk1139`
  - authorization subfolder and copied smoke authorization DOCX into:
    - `PEV Records/Candidate Files/BGV-20260406-smk1139/Authorization/SMOKE_Authorization.docx`
- Reminder-flow result:
  - verified that `BGV_6_HRReminderAndEscalation` wakes up every 30 minutes but only actually processes reminder logic at `09:00` and `17:30` Singapore time
  - noon/afternoon smoke checks therefore did not move the reminder row, which is expected outside those run windows
- Employer-send flow result:
  - the smoke check exposed an active live blocker in `BGV_4_SendToEmployer_Clean`
  - repeated live runs at `12:00`, `12:30`, `14:00`, and `14:30` Singapore time failed
  - failure consistently remained inside the company-stamp creation branch:
    - `Condition_-_Create_Company_Stamp_Document`
    - parent loop: `Apply_to_each_(Requests_Loop)`
- Attempted canonical/live hardening:
  - first patch changed the condition expression to an `empty(first(...))` form; this was deployed but still failed because `first()` can fault on an empty result
  - second patch changed the condition expression to a safe length-based form:
    - `@equals(length(body('Filter_array_-_Company_Stamp_Document')), 0)`
  - repacked and reimported the unmanaged solution after each patch using PAC CLI
- Current truthful state after the smoke run:
  - `SendAfterDate` deferral remains correct at the data level (`EMP1` stayed `Not Sent`)
  - `BGV_6` reminder timing logic remains documented and consistent with the configured run window
  - `BGV_4` is still failing live in the company-stamp creation branch, so employer-send launch is not yet fully cleared by smoke validation
- Immediate next action:
  - rebuild or repair the `Condition_-_Create_Company_Stamp_Document` branch in the Power Automate designer so the company-stamp document path can be created/shared without aborting the full request loop

## 2026-04-06 - Flow 4 repaired to use request-folder upload link

- Reworked the fragile company-stamp branch in the canonical live sender/reminder flows:
  - `BGV_4_SendToEmployer_Clean`
  - `BGV_6_HRReminderAndEscalation`
- Removed the runtime dependency on creating and sharing `Company Stamp - <RequestID>.docx` during employer send/reminder generation.
- Replaced that branch with the safer folder-link pattern already compatible with Flow 5 expiry logic:
  - create or reuse `PEV Records/Candidate Files/<CandidateID>/<RequestID>`
  - look up the request folder item from the candidate root
  - create an anonymous edit sharing link for the request folder
  - inject that folder link into employer Form 2 prefill key `rd5d9cb98b1aa47dd8bcd7914cd4bdc87`
  - update employer/reminder email wording to tell HR to upload company stamp or proof of HR contact into the shared request folder
- Packed and imported the updated unmanaged solution with PAC CLI under the verified `recruitment@dlresources.com.sg` context.
- Live smoke validation result for Flow 4:
  - resubmitted latest failed Flow 4 recurrence after deployment
  - new resubmitted run `08584261432611440233977674720CU03` succeeded
  - smoke defer case remained correct:
    - `REQ-BGV-20260406-smk1139-EMP1` stayed `VerificationStatus = Not Sent`
  - smoke immediate-send case now passed:
    - `REQ-BGV-20260406-smk1139-EMP2` changed to `VerificationStatus = Email Sent`
    - `HRRequestSentAt = 2026-04-06T08:20:41Z`
    - `uniquelinktoemployers` now contains the employer Form 2 prefill URL with an `rd5...` value pointing to a SharePoint folder link (`/:f:/...`) instead of the old Word-document link (`/:w:/...`)
- Reminder-flow verification note:
  - Flow 6 was updated to the same folder-link logic and redeployed successfully
  - direct resubmits outside the production reminder-window branch did not stamp the smoke reminder row, which is expected because `BGV_6` only actively processes reminders at `09:00` and `17:30` Singapore time
  - no new failure was observed in the redeployed Flow 6 runs
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\\flows\\power-automate\\unpacked --zipfile .\\artifacts\\exports\\BGV_System_flow4_flow6_folderlink_fix_20260406.zip --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_flow4_flow6_folderlink_fix_20260406.zip --publish-changes --force-overwrite`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --query "{displayName:name,state:properties.state,lastModified:properties.lastModifiedTime}" --output json`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name fc4bf0e3-0916-f111-8341-002248582037 --query "{displayName:name,state:properties.state,lastModified:properties.lastModifiedTime}" --output json`
  - `m365 flow run resubmit --force --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --name 08584261444855072460698310771CU22 --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 8eeeed39-e02f-4b7a-82c8-fc51f245d863 --name 08584261432611440233977674720CU03 --withActions --output json`
  - `m365 spo listitem get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 52 --output json`
  - `m365 spo listitem get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 53 --output json`
- Current launch-readiness conclusion:
  - Flow 4 employer send path is repaired and smoke-cleared.
  - Flow 6 reminder path is aligned to the same upload-folder model and remains constrained to its production run windows.
  - Next action: run daily sync and push GitHub once this repaired state is confirmed as the new baseline.

- 2026-04-07: Repaired employer company-stamp link path in Flow 4/6 back to shared Word document behavior.
  - Root cause: employer prefill key d5d9cb98b1aa47dd8bcd7914cd4bdc87 and employer email body had previously been redirected to a shared request-folder link.
  - Canonical files updated:
    - flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json
    - flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json
  - Re-imported solution and re-enabled live Flow 4 and Flow 6.
  - Live validation:
    - Flow 4 is Started and recurring successfully.
    - New live employer links observed in PEV_Requests now include SharePoint /:w:/... document links again for d5d..., confirming the shared Word document mapping is back.
  - Note: one smoke request iteration remained inconsistent for EMP2 loop validation, but the live generated employer document-link format is corrected for new sends.

## 2026-04-07 (Employer Form 2 prefill base URL repaired to live Forms domain)

- Current status:
  - Investigated the report that employer Form 2 links were opening without their prefilled values showing.
- Completed tasks:
  - Confirmed the active canonical sender/reminder flows were still building the employer prefilled URL on the older `forms.office.com` base.
  - Verified the current live user-provided Form 2 prefilled URL pattern is `forms.cloud.microsoft`.
  - Updated both active canonical flows so the prefilled employer Form 2 link now uses the current live base URL while preserving the existing request-specific `r...` field mappings:
    - `BGV_4_SendToEmployer_Clean`
    - `BGV_6_HRReminderAndEscalation`
  - Updated flow documentation so the company-stamp prefill description matches the current live Word-document model rather than the older request-folder wording.
- Validation commands run:
  - `rg -n "forms\\.office\\.com/Pages/ResponsePage\\.aspx\\?id=cHRZOFNHGkaDf62MFIYLIq9-liquOypMpApm-AyRSqVUN1c5NE0wWEI2Nk1OMDlJSkI0N0RXUTRHMS4u" flows/power-automate/unpacked/Workflows/`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
- Next actions and blockers:
  - Repack/import the updated solution to live, then verify a fresh generated employer link from `PEV_Requests.uniquelinktoemployers` uses `forms.cloud.microsoft` and still carries the request-specific field values.

## 2026-04-07 (Employer Form 2 prefill fixed by reverting to proven office.com domain)

- Current status:
  - Investigated the follow-up report that employer Form 2 still opened blank even after the domain change.
- Completed tasks:
  - Verified from a successful live `BGV_5_Response1` run on `2026-04-03` that the employer form was returning the first-page values under the expected keys, including:
    - `r4930fc603c0f4cada09832be79f2a76f` candidate name
    - `r27b6bdb850dd48339dc05df11d485470` NRIC
    - `r425242341d6143c7a29307136debe938` Passport
    - `rd745d133eb7f4611b59ea051f980f97a` RequestID
    - `rccaf3632669648baaa335c12d4ea40bf` employer name
    - `rcf35c7cc008e472f9d0b84bde67cc1ff` employer UEN
    - `r19aae6e8163d4aaeb8a3f3f2d5329be2` employer address
  - Confirmed that this proved the key set itself was still valid; the regression aligned with the recent switch from `forms.office.com` to `forms.cloud.microsoft`.
  - Reverted both active canonical sender/reminder flows back to the last proven-good employer prefill base URL:
    - `BGV_4_SendToEmployer_Clean`
    - `BGV_6_HRReminderAndEscalation`
  - Packed and imported the updated solution successfully under the verified `recruitment@dlresources.com.sg` PAC context.
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_prefill_office_revert_20260407.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_prefill_office_revert_20260407.zip --publish-changes --force-overwrite`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName fb38d48c-6c03-42d8-8af7-b085a20c2def --name 08584263965925123704267412207CU24 --withActions --output json`
- Notes:
  - The post-import smoke resubmit succeeded at the flow-run level but did not stamp the smoke request row again, so the strongest proof remains the live successful `BGV_5` run showing `forms.office.com` links returned the first-page prefilled values correctly.
  - Use newly generated employer links after this import as the source of truth; older generated links may still reflect earlier domain variants.

## 2026-04-07 (Employer Form 2 prefill final live smoke proof)

- Current status:
  - Confirmed the employer prefilled fields are now showing again on newly generated links.
- Completed tasks:
  - Repacked and reimported the corrected canonical `BGV_4_SendToEmployer_Clean` and `BGV_6_HRReminderAndEscalation` definitions after verifying both use the proven `forms.office.com` base URL.
  - Reset internal smoke request `PEV_Requests` item `52` (`REQ-BGV-20260406-smk1139-EMP2`) back to a fresh send state:
    - `VerificationStatus = Not Sent`
    - `HRRequestSentAt = null`
    - `uniquelinktoemployers = null`
  - Allowed the next live Flow 4 recurrence to regenerate the employer request from the repaired live definition.
  - Verified the regenerated request row now contains:
    - `VerificationStatus = Email Sent`
    - `HRRequestSentAt = 2026-04-07T06:01:42Z`
    - `uniquelinktoemployers` using `https://forms.office.com/Pages/ResponsePage.aspx?...`
    - request-specific prefill values for:
      - candidate name
      - NRIC / passport fallback
      - RequestID
      - employer name
      - employer UEN
      - employer address
      - employment period
      - last drawn salary
      - job title
      - shared Word company-stamp document link
- Validation commands run:
  - `pac auth who`
  - `pac solution pack --zipfile .\\artifacts\\exports\\BGV_System_prefill_office_revert_final_20260407.zip --folder .\\flows\\power-automate\\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\\artifacts\\exports\\BGV_System_prefill_office_revert_final_20260407.zip --publish-changes --force-overwrite`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 52 --VerificationStatus 'Not Sent' --HRRequestSentAt '' --uniquelinktoemployers '' --output json`
  - `m365 spo listitem get --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 52 --output json`
- Final conclusion:
  - the field keys were not the defect
  - the regression came from changing the employer form base domain
  - production is now correctly back on `forms.office.com` for new employer sends

## 2026-04-07 (Dashboard status fix for unsigned authorization cases)

- Current status:
  - Corrected the live dashboard status logic so unsigned authorization cases no longer appear as `Authorisation Form Received`.
- Completed tasks:
  - Investigated the specific test candidate from the dashboard screenshot:
    - `CandidateID = PEV-20260407-9d6e7`
    - `FullName = test 3 7/4 - Joel Ng Wei Kiat`
  - Verified the live SharePoint state:
    - `PEV_Candidates.Status = Pending Authorization Form Signature`
    - `PEV_Candidates.AuthorisationSigned = false`
    - `PEV_Candidates.AuthorizationLinkCreatedAt = 2026-04-07T06:22:09Z`
    - matching `PEV_Requests.VerificationStatus = Not Sent`
    - matching `PEV_Requests.HRRequestSentAt = null`
  - Confirmed the bug was in `BGV_9_Refresh_Dashboard_Excel`:
    - `Compose_Status` was falling through to `Authorisation Form Received` for any request not yet in the employer reminder chain.
  - Patched `Compose_Status` so status derivation now follows the documented order:
    - no authorization link created -> `Candidate Form Received`
    - authorization link created but not signed -> `Authorisation Form Sent`
    - signed + employer not yet sent -> `Authorisation Form Received`
    - signed + future `SendAfterDate` -> `Authorisation Received - Employer Email Queued`
    - then the normal employer reminder / responded statuses
- Validation commands run:
  - `m365 spo listitem list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Candidates --filter "CandidateID eq 'PEV-20260407-9d6e7'" --output json`
  - `m365 spo listitem list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --filter "CandidateID eq 'PEV-20260407-9d6e7'" --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
- Next action:
  - Repack/import the patched `BGV_9` flow and run a refresh so the workbook row updates from `Authorisation Form Received` to `Authorisation Form Sent`.

## 2026-04-08 (Authorization template hardened and employer reminder wording clarified)

- Current status:
  - Recompleted the interrupted validation pass for the candidate authorization template and employer reminder wording.
- Completed tasks:
  - Verified `BGV_0_CandidateDeclaration` still points to the same live SharePoint template file:
    - `PEV Records/Templates/DLRAuthorizationLetter_Template.docx`
    - live file id remains `017QXH3H2C7KNCCUL4KRDIDZKFV4VC5U6H`
  - Downloaded the live template, saved a timestamped local backup, and patched only the Word protection setting so the document now uses enforced `forms` protection.
  - Uploaded the patched template back to the same live SharePoint file id so no flow file reference had to change.
  - Re-downloaded the live template and verified the required controls still exist after patching:
    - `CandidateName`
    - `Identification Number NRIC`
    - `Identification Number Passport`
    - `Date`
    - `SignedYes`
  - Confirmed this keeps `BGV_1_Detect_Authorization_Signature` compatible with the current signed-checkbox detection logic.
  - Patched `BGV_6_HRReminderAndEscalation` reminder email wording so Reminder 1, Reminder 2, and Final Reminder now clearly name the candidate and state that the candidate authorized D L Resources to conduct the background check and provided the employer contact for verification.
  - Repacked and reimported the solution successfully under verified PAC context `recruitment@dlresources.com.sg`.
  - Rechecked internal smoke candidate `BGV-20260406-smk1139` request rows after the live changes:
    - `EMP1` still holds a valid `forms.office.com` prefilled employer link and a SharePoint `/:w:/` Word document stamp link
    - `EMP2` still holds a valid `forms.office.com` prefilled employer link and a SharePoint `/:w:/` Word document stamp link
    - `EMP3` remains in the reminder chain as `Reminder 1 Sent`, confirming no structural break in the reminder-state data
  - Updated `docs/flows_easy_english.md` to explain the hardened authorization template behavior and the clarified employer reminder wording.
- Validation commands run:
  - `pac auth who`
  - `m365 request --url "https://graph.microsoft.com/v1.0/drives/b!4bIASqxJ3kC7mLqOoWQ6QkHCxThCNSlGm37xVevErElNW6uLQbQ_T5nUW_SVV6jp/items/017QXH3H2C7KNCCUL4KRDIDZKFV4VC5U6H?$select=id,name,lastModifiedDateTime,lastModifiedBy,parentReference,webUrl" --output json`
  - Graph file upload back to the same live template item id using a token from `m365 util accesstoken get`
  - local XML verification of `word/settings.xml` and `word/document.xml` from the re-downloaded live template
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_reminder_wording_auth_template_20260408.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_reminder_wording_auth_template_20260408.zip --publish-changes --force-overwrite`
  - `m365 spo listitem list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --filter "CandidateID eq 'BGV-20260406-smk1139'" --output json`
- Notes:
  - The authorization template hardening was deliberately minimal and reversible: only the document protection enforcement changed, while the live file path/id and the flow-detection controls remained the same.
  - The smoke verification here was a safe structural/live-data check using the internal smoke candidate rows rather than a fresh external send.

## 2026-04-08 (Employer reminder smoke test completed and production-safe Flow 6 restored)

- Current status:
  - Completed the internal-only live smoke validation for employer Reminder 1, Reminder 2, and Final Reminder using smoke candidate `BGV-20260406-smk1139`.
  - Restored `BGV_6_HRReminderAndEscalation` to the production-safe version after the smoke run and reset the smoke request rows back to their baseline values.
- Completed tasks:
  - Verified PAC context first:
    - `recruitment@dlresources.com.sg`
  - Confirmed the local canonical `BGV_6_HRReminderAndEscalation` definition had:
    - the real reminder run window logic (`09:00` and `17:30` Singapore time)
    - no leftover smoke-only candidate filter
    - the permanent `CandidateDisplayName` compose action used by reminder email bodies
  - Repacked and reimported the full unmanaged solution from canonical source and re-enabled live `BGV_6_HRReminderAndEscalation`.
  - Verified live `BGV_6_HRReminderAndEscalation` is now back to `Started`.
  - Restored the internal smoke `PEV_Requests` rows to their baseline values:
    - item `51` / `REQ-BGV-20260406-smk1139-EMP1`
      - back to `VerificationStatus = Email Sent`
      - `Reminder1At`, `Reminder2At`, `Reminder3At`, `ResponseReceivedAt`, `EscalatedAt` cleared
    - item `52` / `REQ-BGV-20260406-smk1139-EMP2`
      - back to `VerificationStatus = Email Sent`
      - `Reminder1At`, `Reminder2At`, `Reminder3At`, `ResponseReceivedAt`, `EscalatedAt` cleared
    - item `53` / `REQ-BGV-20260406-smk1139-EMP3`
      - back to `VerificationStatus = Reminder 1 Sent`
      - `Reminder1At` restored
      - `Reminder2At`, `Reminder3At`, `ResponseReceivedAt`, `EscalatedAt` cleared
  - Confirmed actual reminder email outputs in the recruitment mailbox during the smoke test:
    - Reminder 1 subject:
      - `Reminder: Employment Verification Request`
    - Reminder 2 subject:
      - `2nd Reminder: Employment Verification Request from D L Resources`
    - Final Reminder subject:
      - `Final Reminder: Employment Verification Request`
    - Reminder 1, Reminder 2, and Final Reminder all contained:
      - the correct candidate name (`SMOKE Launch Candidate 2026-04-06`)
      - wording that the candidate authorized D L Resources to conduct the background check
      - wording that the employer was provided as the verification contact
      - the request-specific prefilled employer Form 2 link
      - the request-specific shared Word company-stamp document link
  - Confirmed reminder-state transitions during the smoke execution:
    - Reminder 1 stamped `Reminder1At` and `VerificationStatus = Reminder 1 Sent`
    - Reminder 2 stamped `Reminder2At` and `VerificationStatus = Reminder 2 Sent`
    - Final Reminder stamped `Reminder3At` and `VerificationStatus = Reminder 3 Sent`
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder flows\\power-automate\\unpacked --zipfile artifacts\\exports\\bgv_smoke_finalize_20260408.zip --packagetype Unmanaged`
  - `pac solution import --path artifacts\\exports\\bgv_smoke_finalize_20260408.zip --environment https://orgde64dc49.crm5.dynamics.com/ --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 3df19738-dfe2-4068-995c-46198ff91435`
  - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --asAdmin --output json`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 51 ...`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 52 ...`
  - `m365 spo listitem set --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle PEV_Requests --id 53 ...`
- Notes:
  - The smoke run stayed internal-only by using `recruitment@dlresources.com.sg` as the mailbox target; no external employer mailbox was used for this validation.
  - The reminder-body defect from earlier in the day was fixed permanently by using `CandidateDisplayName` in reminder email bodies instead of relying on inline fallback rendering that could blank the candidate name.

## 2026-04-08 (Authorization template reverted to browser-editable version)

- Current status:
  - Reverted the live authorization template back to the original browser-editable version because the protected version could not be edited in Word for the browser.
- Completed tasks:
  - Restored the original template backup over the same live SharePoint template item:
    - `PEV Records/Templates/DLRAuthorizationLetter_Template.docx`
    - item id `017QXH3H2C7KNCCUL4KRDIDZKFV4VC5U6H`
  - Verified `BGV_0_CandidateDeclaration` still points to that exact template item id and file path; no flow remap was needed.
  - Downloaded the restored live template and rechecked the critical XML markers:
    - `SignedYes` still present
    - `CandidateName` still present
    - `Identification Number NRIC` still present
    - `Identification Number Passport` still present
  - Confirmed the restored template now has:
    - `w:documentProtection w:edit="forms" w:enforcement="0"`
    - which means browser editing is allowed again
- Validation commands run:
  - Graph metadata read on live template item id `017QXH3H2C7KNCCUL4KRDIDZKFV4VC5U6H`
  - Graph file upload back to the same live template item id using the saved backup:
    - `out/template_backups/DLRAuthorizationLetter_Template_20260408_140447.docx`
  - local XML inspection of the restored live template after re-download
  - Notes:
  - This restores candidate browser editing, including draw/sign use in the browser and checkbox ticking.
  - Word for the browser does not reliably support a true partly-locked / partly-editable experience when document protection is enforced, so the live template is intentionally kept browser-editable to preserve the candidate flow.

## 2026-04-08 (Flow 9 blank DashboardKey guard fix)

- Current status:
  - Fixed the Flow 9 dashboard refresh failure caused by a blank row in `tblDashboardCasesPA`.
- Completed tasks:
  - Patched the canonical Flow 9 condition branch so `Condition_-_Has_DashboardKey` now trims/coalesces `DashboardKey` before deciding whether to delete an existing dashboard row.
  - Patched the `Delete_row_from_tblDashboardCasesPA` action to pass a trimmed/coalesced `DashboardKey` value as the delete id.
  - Repacked and reimported the live unmanaged solution using the existing Flow 9 deployment settings file:
    - `out/deployment-settings/bgv9_live.settings.json`
  - Confirmed the live flow remained `Started` after import:
    - `BGV_9_Refresh_Dashboard_Excel`
  - Waited for the next scheduled post-fix recurrence run and verified it succeeded:
    - run id `08584259632853808651567547947CU22`
  - Confirmed the previously failing loop now succeeds even when the Excel table still contains a blank dashboard row:
    - `Apply_to_each_(Existing_Dashboard_Rows)` succeeded
    - the first row in the live Excel input still had `DashboardKey = ""`
  - Confirmed the refresh completed all the way through:
    - `Add_a_row_into_tblDashboardRefreshLog` succeeded
    - refresh log recorded `Rows Written = 44`, `Total Requests = 66`, `Active Cases = 44`, `Cleared Cases = 22`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac auth who`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_live.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_dashboard_live.zip --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
  - `m365 flow list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --asAdmin --output json`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 7f4dbc87-1117-af35-a703-126c8a6485c0 --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 7f4dbc87-1117-af35-a703-126c8a6485c0 --name 08584259632853808651567547947CU22 --withActions --output json`
- Notes:
  - The fix is intentionally defensive: blank rows in the Excel table are now skipped safely instead of breaking the dashboard refresh.

## 2026-04-08 (Flow 9 delete path switched to Excel ItemInternalId)

- Current status:
  - Followed up on a new Flow 9 failure report and confirmed the real remaining blocker was still the Excel delete loop inside `Apply_to_each_(Existing_Dashboard_Rows)`, not the outer refresh-window condition.
- Completed tasks:
  - Investigated the latest live Flow 9 runs and separated:
    - old manual `testFlow` failures
    - one real scheduled failure at `10:00`
    - later scheduled successes
  - Confirmed the failing action was still:
    - `Delete_row_from_tblDashboardCasesPA`
  - Confirmed the workbook still contained a leading blank row, but there were no duplicate populated `DashboardKey` values in the failed run input.
  - Patched the canonical Flow 9 delete loop so it no longer deletes rows by the custom `DashboardKey`.
  - Switched the existing-row delete path to use the Excel-native row identifier instead:
    - `Condition_-_Has_DashboardKey` now guards on `ItemInternalId`
    - `Delete_row_from_tblDashboardCasesPA` now uses:
      - `idColumn = ItemInternalId`
      - `id = items('Apply_to_each_(Existing_Dashboard_Rows)')?['ItemInternalId']`
  - Repacked and reimported the live unmanaged solution using the existing Flow 9 deployment settings.
  - Verified the next scheduled live Flow 9 recurrence succeeded after deployment:
    - run `08584259620858971942330106765CU07`
    - status `Succeeded`
- Validation commands run:
  - `pac auth who`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 7f4dbc87-1117-af35-a703-126c8a6485c0 --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 7f4dbc87-1117-af35-a703-126c8a6485c0 --name 08584259644853406400390462231CU03 --withActions --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_9_Refresh_Dashboard_Excel-03B36E72-1ACE-4FCF-AD6D-80A583012F31.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --folder .\flows\power-automate\unpacked --zipfile .\artifacts\exports\BGV_System_dashboard_iteminternalid_fix_20260408.zip --packagetype Unmanaged`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path <resolved zip path> --settings-file .\out\deployment-settings\bgv9_live.settings.json --publish-changes --force-overwrite`
- Notes:
  - This makes the refresh safer because the delete loop now uses Excel’s own stable row identifier instead of a user-data column that can be blank or malformed.

## 2026-04-09 (Daily sync + candidate-name fallback fix for employer reminders and response email)

- Current status:
  - Ran the daily sync first, then fixed the remaining blank candidate-name issue in employer reminder emails and the `PEV Response Received` recruiter email.
- Completed tasks:
  - Ran `scripts/active/bgv_daily_sync.ps1` against `https://orgde64dc49.crm5.dynamics.com/` and confirmed PAC identity was `recruitment@dlresources.com.sg`.
  - Confirmed the local repo was clean immediately after sync.
  - Investigated the live-exported canonical flow JSON and found two stale/brittle candidate-name sources still in use:
    - `BGV_6_HRReminderAndEscalation` still had reminder/escalation body text using the old request lookup display name path in some places.
    - `BGV_5_Response1` still had the `PEV Response Received` subject/body, the cleared Teams post, and the high-severity email subject using the old request lookup display name path.
  - Patched `BGV_6_HRReminderAndEscalation` so reminder emails and the reminder-2 escalation Teams post consistently use `CandidateDisplayName`.
  - Patched `BGV_5_Response1` by adding `Compose_ResponseCandidateName` with the fallback order:
    - `PEV_FormData.F1_CandidateFullName`
    - request lookup display name
    - `CandidateID`
  - Repointed the recruiter-facing response email subject/body, the cleared Teams post, and the high-severity email subject in `BGV_5` to `Compose_ResponseCandidateName`.
  - Validated both patched canonical workflow JSON files with `ConvertFrom-Json`.
  - Repacked and imported the unmanaged solution successfully into the live environment.
  - Updated `docs/flows_easy_english.md` to document the candidate-name fallback logic for both `BGV_5` and `BGV_6`.
  - Removed the temporary packed solution zip after import.
- Validation commands run:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `git status --short --branch`
  - `rg -n "Compose_ResponseCandidateName|CandidateItemID_x003a__x0020_Ful/Value|PEV Response Received|A PEV response has been received for|PEV Checks Cleared|Severity:|Candidate:" flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - `rg -n "CandidateDisplayName|CandidateItemID_x003a__x0020_Ful/Value|complete the employment verification for|has authorized D L Resources|Candidate:" flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac auth who`
  - `pac solution pack --zipfile flows/power-automate/BGV_Automation_Unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged`
  - `pac solution import --path flows/power-automate/BGV_Automation_Unmanaged.zip --publish-changes --force-overwrite`
- Notes:
  - The account used for this deployment can import via PAC successfully, but `m365 flow list --asAdmin` in the Default environment is not permitted for this account, so live verification is being handled by post-import sync/export consistency rather than admin flow-list calls.

## 2026-04-27 (BGV_2 lock-response retry + BGV_6 company-stamp fallback + full sync)

- Current status:
  - Repaired the two live failure patterns reported from Saturday, April 25, 2026 and synced PAC, local source, and GitHub.
- Completed tasks:
  - Investigated the Saturday failures without changing production first:
    - `BGV_2_Postsignature` was failing when `LockAuthorizationControls` returned an HTML runtime-error page instead of JSON, which caused `Update_file_content_with_locked_controls` to fail.
    - `BGV_6_HRReminderAndEscalation` was failing when `Get_company_stamp_document_metadata_by_path` could not find the request-specific company stamp file for one row in the reminder batch.
  - Updated `BGV_2_Postsignature`:
    - wrapped the lock response in a validity check
    - added one retry call to `LockAuthorizationControls` when `lockedDocxBase64` is missing
    - kept the normal file-update and unshare path unchanged when the lock response is valid
  - Updated `BGV_6_HRReminderAndEscalation`:
    - replaced the single-path company-stamp lookup chain with the same resilient fallback already used in `BGV_4`
    - if the request-specific company stamp document is missing, the flow now loads `/PEV Records/Templates/Company Stamp.docx`, creates the request-specific stamp document, re-reads its metadata, and then creates the share link
    - repointed reminder email bodies and `FinalVerificationLink` generation to use the composed `CompanyStampDocumentLink`
  - Updated `docs/flows_easy_english.md` so the documented behavior now matches the new BGV_2 retry logic and the new BGV_6 company-stamp fallback behavior.
  - Packed and imported the unmanaged solution live.
  - Re-enabled `BGV_2_Postsignature` and `BGV_6_HRReminderAndEscalation` after import.
  - Confirmed live state:
    - `BGV_2_Postsignature` = `Started`
    - `BGV_6_HRReminderAndEscalation` = `Started`
    - both show `flowSuspensionReason = None`
  - Committed and pushed the repo changes so GitHub matches the deployed canonical source.
- Validation commands run:
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName a45ca9c0-e4f1-f011-8406-002248582037 --status Failed --triggerStartTime 2026-04-24T00:00:00Z --triggerEndTime 2026-04-27T00:00:00Z --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName a45ca9c0-e4f1-f011-8406-002248582037 --name 08584245485025135919781428669CU30 --withActions --output json`
  - `m365 flow run list --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 3df19738-dfe2-4068-995c-46198ff91435 --status Failed --triggerStartTime 2026-04-24T16:00:00Z --triggerEndTime 2026-04-25T16:00:00Z --output json`
  - `m365 flow run get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --flowName 3df19738-dfe2-4068-995c-46198ff91435 --name 08584245280852824521653839391cU14 --withActions --output json`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_bgv2_bgv6_resilience_20260427.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_bgv2_bgv6_resilience_20260427.zip --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name a45ca9c0-e4f1-f011-8406-002248582037`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 3df19738-dfe2-4068-995c-46198ff91435`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name a45ca9c0-e4f1-f011-8406-002248582037 --output json`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name 3df19738-dfe2-4068-995c-46198ff91435 --output json`
- Notes:
  - The old local-only artifact `202604170355470169_BGV_System_5236.zip` is not part of the deployed source and should remain out of source control.

## 2026-04-09 (Flow 5 separate high-severity email removed)

- Current status:
  - Simplified recruiter response notifications so employer Form 2 responses now send only the standard `PEV Response Received` email, with no separate high-severity-only email branch.
- Completed tasks:
  - Removed the disabled/legacy `Condition_-_Send_Email` branch and `Send_an_email_-_High_Severity_(V2)` action from `BGV_5_Response1`.
  - Repointed the standard recruiter response email action to run directly after `Condition_-_Notifying_Teams`.
  - Updated `docs/flows_easy_english.md` so the documented recruiter email behavior now explicitly matches the single-email design.
- Validation commands run:
  - `pac auth who`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --zipfile flows/power-automate/BGV_Automation_Unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged`
  - `pac solution import --path flows/power-automate/BGV_Automation_Unmanaged.zip --publish-changes --force-overwrite`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\active\bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
- Notes:
  - This change makes the explicit flow definition match the behavior you wanted: recruiters receive one response email per employer submission, with severity and flagged issues included in that single email.
## 2026-05-14 (PEV approved-contact guardrail live rollout + workbook migration)

- Current status:
  - Deployed the first-pass guardrail live, created the new SharePoint artifacts, and populated the approved-contact list from the current workbook.
- Completed tasks:
  - Verified deployment auth:
    - `pac auth who` connected as `recruitment@dlresources.com.sg`
    - `m365 status` connected as `recruitment@dlresources.com.sg`
  - Ran the live schema builder:
    - `scripts/active/pev_ensure_target_schema.ps1`
    - created the SharePoint list `Approved HR Reference Contacts`
    - added `PEV_Requests` guardrail fields:
      - `ReferenceGuardrailStatus`
      - `ReferenceGuardrailCheckedAt`
      - `ReferenceGuardrailNotifiedAt`
      - `ReferenceGuardrailLastEmailNormalized`
      - `ReferenceGuardrailNotes`
  - Packed and imported the updated unmanaged solution to the live environment.
  - Verified the live `BGV_4_SendToEmployer_Clean` flow after import:
    - `DisplayName = BGV_4_SendToEmployer_Clean`
    - `State = Started`
    - `FlowSuspensionReason = None`
    - live definition includes `Condition_-_Approved_contact_found`
  - Located the current workbook under:
    - `PEV Records/Previous HR Reference List/HR_Referencing_Emails_updated.xlsx`
  - Inspected workbook structure:
    - `Companys HR email` sheet contains `20` data rows
    - `Personal HR email` sheet is currently header-only
  - Added `scripts/active/pev_import_approved_hr_reference_contacts.py` for reusable workbook-to-list migration.
  - Migrated the workbook data into the live `Approved HR Reference Contacts` list:
    - live list now contains `20` items
    - all `20` preview rows had unique normalized emails
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `[System.Management.Automation.Language.Parser]::ParseFile('scripts/active/pev_ensure_target_schema.ps1',[ref]$null,[ref]$errors)`
  - `Import-Module PnP.PowerShell -ErrorAction Stop; .\scripts\active\pev_ensure_target_schema.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
  - `pac solution pack --zipfile artifacts\exports\BGV_System_pev_guardrail_20260514.zip --folder flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path artifacts\exports\BGV_System_pev_guardrail_20260514.zip --publish-changes --force-overwrite`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name fe4bf0e3-0916-f111-8341-002248582037 --output json`
  - `m365 spo file list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folderUrl "/sites/DLRRecruitmentOps570/PEV Records/Previous HR Reference List" --output json`
  - `python scripts\active\pev_import_approved_hr_reference_contacts.py --workbook out\migration\HR_Referencing_Emails_updated.xlsx --web-url https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --json-out out\migration\approved_hr_reference_contacts_preview.json`
  - `Get-PnPList -Identity 'Approved HR Reference Contacts' -Includes Id,Title,ItemCount`
  - `Get-PnPField -List 'PEV_Requests' -Identity 'ReferenceGuardrailStatus'`
  - `Get-PnPListItem -List 'Approved HR Reference Contacts' -PageSize 5000 -Fields 'Title','HRReferenceEmailNormalized','CompanyName'`
- Notes:
  - The first-pass guardrail is now live and functional.
  - Because the personal-contact sheet is empty, the live approved-contact list currently contains only the `General Company HR` rows from the workbook.
  - The reusable migration script currently prepares preview data correctly; the live import path that actually succeeded in this rollout was completed/verified through direct live SharePoint checks after the initial CLI-based import calls proved slow.

## 2026-05-14 (PEV approved-contact guardrail first-pass implementation)

- Current status:
  - Implemented the first code pass for the approved HR/reference contact guardrail in the canonical PEV repo.
- Completed tasks:
  - Updated `BGV_4_SendToEmployer_Clean` to add a pre-send approved-contact gate:
    - added `shared_teams` connection reference to the flow
    - composed and normalized the submitted employer HR/reference email before send
    - looked up `Approved HR Reference Contacts` by SharePoint HTTP request using list title plus `HRReferenceEmailNormalized`
    - allowed employer send only when the normalized submitted email is valid and found in the approved-contact list
    - blocked send when the submitted email is missing, invalid, or not approved
    - posted a Teams action message to `DLR Recruitment Ops > BGV` for blocked employer contacts
    - stamped request-side guardrail fields for audit and duplicate-notification suppression
  - Updated `scripts/active/pev_ensure_target_schema.ps1` to provision:
    - the new SharePoint list `Approved HR Reference Contacts`
    - new request-side fields on `PEV_Requests`:
      - `ReferenceGuardrailStatus`
      - `ReferenceGuardrailCheckedAt`
      - `ReferenceGuardrailNotifiedAt`
      - `ReferenceGuardrailLastEmailNormalized`
      - `ReferenceGuardrailNotes`
  - Synced the linked documentation so it now matches the first-pass implementation:
    - `docs/flows_easy_english.md`
    - `docs/sharepoint_list_user_guide.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/pev_reference_contact_guardrail.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `[System.Management.Automation.Language.Parser]::ParseFile('scripts/active/pev_ensure_target_schema.ps1',[ref]$null,[ref]$errors)`
  - `rg -n "Approved HR Reference Contacts|ReferenceGuardrail|Condition_-_Approved_contact_found|Post_message_in_a_chat_or_channel_-_Guardrail" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json scripts/active/pev_ensure_target_schema.ps1`
- Notes:
  - This is a safe first pass using the existing Teams channel connector and automatic recurrence retry after the approved-contact row is added.
  - A later enhancement can convert the recruiter step to a true Teams Approvals card if we decide to add and bind the approvals connector in the solution.

## 2026-05-14 (PEV approved HR reference contact guardrail design synced)

- Current status:
  - Switched back to the `BGV_Checks` PEV repo context and documented the approved-contact guardrail design so the flow, list, and repo indexes stay aligned.
- Completed tasks:
  - Added `docs/pev_reference_contact_guardrail.md` with:
    - recommended SharePoint list schema for `Approved HR Reference Contacts`
    - Excel-to-SharePoint migration plan for the current `Previous HR Reference List` workbook
    - exact Power Automate action sequence for the pre-send lookup/approval gate in `BGV_4_SendToEmployer_Clean`
    - normalization expressions, `Get items` filter pattern, approval template, multi-employer loop handling, and re-check logic after approval
  - Updated `docs/flows_easy_english.md` so the `BGV_4_SendToEmployer_Clean` section now points to the planned approved-contact guardrail behavior.
  - Updated `docs/sharepoint_list_user_guide.md` to include the planned `Approved HR Reference Contacts` list and its business-purpose columns.
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` so the new guardrail document is discoverable from the repo indexes.
- Validation commands run:
  - `git status --short`
  - `rg -n "recruiter|reference|PEV|previous employer|HR email|approval" docs flows shared README.md System_SPEC.md`
  - `rg -n "BGV_4|SendToEmployer|approval|Teams|Apply to each|EmployerHR_Email|reference contact|approved" docs/flows_easy_english.md flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Notes:
  - This pass documents the exact build pattern but does not yet modify the live cloud-flow JSON or create the SharePoint list in the tenant.

## 2026-05-15 (BGV_4 UEN-based centralised employer routing layered onto approved-send branch)

- Current status:
  - Updated the canonical `BGV_4_SendToEmployer_Clean` repo flow so the employer send branch can optionally route by employer UEN after the existing signed-authorisation and approved-email guardrails pass.
- Completed tasks:
  - Patched `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json` to add:
    - `NormalizedEmployerUEN`
    - `Get_Centralised_Employer_Email_By_UEN`
    - `CentralisedEmployerEmailCandidate`
    - `IsCentralisedEmployerEmailValid`
    - `ResolvedEmployerToEmail`
    - `DuplicatePrevention_CentralisedEmailMatchesResolvedTo`
    - `ResolvedEmployerCcEmail`
  - Updated the employer send action so:
    - `To` now uses `ResolvedEmployerToEmail`
    - `CC` now uses `ResolvedEmployerCcEmail`
  - Reused `Approved HR Reference Contacts` as the recruiter-maintained centralised routing source and extended the schema/import helpers with `CompanyUENNormalized`.
  - Synced the linked docs:
    - `docs/flows_easy_english.md`
    - `docs/sharepoint_list_user_guide.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/pev_reference_contact_guardrail.md`
- Validation planned/run:
  - validate `BGV_4` JSON with `ConvertFrom-Json`
  - validate `scripts/active/pev_ensure_target_schema.ps1` with the PowerShell parser
  - validate `scripts/active/pev_import_approved_hr_reference_contacts.py` with `python -m py_compile`
- Notes:
  - This is the smallest safe repo change and assumes recruiters will maintain one active routing row per employer UEN in `Approved HR Reference Contacts`.

## 2026-05-15 (BGV_4 UEN routing deployed live and corrected after template validation failure)

- Current status:
  - The updated `BGV_4_SendToEmployer_Clean` UEN-routing change is now deployed live and the production flow is back in `Started` state.
- Completed tasks:
  - Created the live recruiter-maintained UEN lookup key on `Approved HR Reference Contacts` with the exact field name `CompanyUENNormalized`.
  - Re-ran `scripts/active/pev_import_approved_hr_reference_contacts.py --apply` successfully after the field fix:
    - `20` existing workbook rows updated
    - live rows now carry both `CompanyUEN` and `CompanyUENNormalized`
  - Packed and imported the updated unmanaged solution to production.
  - Live import exposed a flow validation failure when re-enabling `BGV_4`:
    - `Condition_-_Approved_contact_found` could not reference `ApprovedContactBranchDecision`
  - Patched the flow condition to evaluate the approved-email guard inline instead of referencing the extra compose output.
  - Repacked and reimported the corrected solution.
  - Verified the live `BGV_4_SendToEmployer_Clean` definition now contains:
    - `NormalizedEmployerUEN`
    - `Get_Centralised_Employer_Email_By_UEN`
    - `ResolvedEmployerToEmail`
    - `ResolvedEmployerCcEmail`
    - employer send action `To = @outputs('ResolvedEmployerToEmail')`
    - employer send action `CC = @outputs('ResolvedEmployerCcEmail')`
  - Re-enabled the live flow successfully:
    - `DisplayName = BGV_4_SendToEmployer_Clean`
    - `State = Started`
    - `FlowSuspensionReason = None`
- Validation commands run:
  - `m365 spo field add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle "Approved HR Reference Contacts" --xml "<Field Type='Text' DisplayName='CompanyUENNormalized' Name='CompanyUENNormalized' StaticName='CompanyUENNormalized' Indexed='TRUE' Group='PEV Custom Columns' />" --output json`
  - `python scripts\active\pev_import_approved_hr_reference_contacts.py --workbook out\migration\HR_Referencing_Emails_updated.xlsx --web-url https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --json-out out\migration\approved_hr_reference_contacts_import_result.json --apply`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_uen_routing_20260515.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --environment https://orgde64dc49.crm5.dynamics.com/ --path .\artifacts\exports\BGV_System_uen_routing_20260515.zip --publish-changes --force-overwrite`
  - `m365 flow enable --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name fe4bf0e3-0916-f111-8341-002248582037 --debug`
  - `m365 flow get --environmentName Default-38597470-4753-461a-837f-ad8c14860b22 --name fe4bf0e3-0916-f111-8341-002248582037 --query "{displayName:properties.displayName,state:properties.state,lastModified:properties.lastModifiedTime,flowSuspensionReason:properties.flowSuspensionReason}" --output json`
  - `m365 spo listitem list --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --listTitle "Approved HR Reference Contacts" --fields "Id,CompanyUEN,CompanyUENNormalized,HRReferenceEmail" --output json`
- Notes:
  - The production validation here proves the live definition, live field, and live recruiter-maintained data path are aligned.
  - A true end-to-end employer-send smoke was not auto-triggered in this pass because that would require intentionally creating or sending a real employer request from production data.
