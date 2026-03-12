# BGV SharePoint Site Migration Plan

## Summary
- Current production source is `https://dlresourcespl88.sharepoint.com/sites/dlrespl`; target is `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`, and the target site already exists with content that must be preserved.
- The canonical flow source under `flows/power-automate/unpacked/Workflows/` is portability-tokenized (`__BGV_*__`) and guarded by `scripts/active/check_bgv_portability.py`.
- Because you chose `full history + freeze and finish old + separate test environment`, implement this as blue/green: keep the current blue solution on the old site for legacy open cases, stand up a green solution on the new site for all new cases, then do a final legacy-drain copy after blue reaches zero open cases.
- Microsoft Forms cutover decision (low disruption): keep the same existing Form 1 and Form 2 links/questions and redirect only downstream Power Automate/SharePoint bindings to target.

## Execution Status (2026-03-12)
- Completed and verified:
  - inventory generation: `out/migration/inventory.json`
  - closed-history copy + validate: `out/migration/copy_closedhistory.json`, `out/migration/validate_closedhistory.json`
  - legacy-drain copy + validate: `out/migration/copy_legacydrain.json`, `out/migration/validate_legacydrain.json`
  - full-history parity copy + validate:
    - `out/migration/copy_all.json`
    - `out/migration/validate_all.json`
    - result: `BGV_Candidates 5/5`, `BGV_Requests 8/8`, `BGV_FormData 68/68`, `BGV Records files 61/61`
  - target schema generation: `out/migration/target_schema.json`
  - setup parity sync + verification:
    - `out/migration/setup_sync.json`
    - `out/migration/setup_parity.json`
    - result: setup parity now fully aligned (`MismatchCount=0`), including `BGV Records` permission inheritance mode
  - final settings materialization:
    - `out/deployment-settings/final/test.pac.settings.json`
    - `out/deployment-settings/final/test.token-values.json`
    - `out/deployment-settings/final/prod.pac.settings.json`
    - `out/deployment-settings/final/prod.token-values.json`
    - `out/materialized/bgv_green_test_final`
    - `out/materialized/bgv_green_prod_final`
  - blue operational closeout (automated):
    - blue flow set `BGV_0` to `BGV_6` disabled in production environment
    - final blue backup archived at
      `artifacts/exports/BGV_System_blue_final_backup_20260312_022951.zip`
    - closeout audit artifact: `out/migration/closeout_report.json`
  - production runtime audit artifact:
    - `out/migration/production_flow_runtime_status.json`
    - confirms current production `BGV_*` cloud flows are `Stopped`
    - confirms current deployed definitions still reference source site
      `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
      (not target site)
  - production cutover completed in single freeze window:
    - freeze marker: `out/migration/freeze_window.json`
    - pre-cutover backup: `artifacts/exports/BGV_System_pre_green_cutover_20260312_161406.zip`
    - cutover packages:
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_161626.zip`
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_162627.zip`
      - `artifacts/exports/BGV_System_green_prod_cutover_20260312_163244.zip`
    - flow start execution log: `out/migration/green_flow_start_results.json`
    - post-cutover runtime audit: `out/migration/production_flow_runtime_status_after_cutover.json`
    - confirms `BGV_0`..`BGV_6` are `Started`, all reference target site `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`, and none reference source site
  - parity checks currently pass for selected manifest rows/files and portability guard.
- Completed remediation items:
  - target `BGV_Requests.CandidateItemID` lookup binding repaired to target `BGV_Candidates` list ID.
  - copy script now handles target file path translation and idempotent nested folder creation reliably.
  - form-data numeric ID remap (`CandidateItemID`, `RecordItemID`) is applied to target-site item IDs.
  - BGV flow definitions hardened for target-site activation:
    - added required `item/Title` payload in candidate/request create and patch actions where SharePoint connector validation required it at flow start time.
- Pending/manual steps:
  - Step 6 test-environment smoke validation remains required as an operational signoff artifact (production cutover is complete, but test evidence should still be recorded).
  - No Forms decommission is required for this chosen model (same links kept); only confirm Forms ownership/sharing and user communications still point to the same approved links.
  - Operational signoff only: run final end-to-end smoke test evidence for `BGV_0`..`BGV_6` in production.

## Interfaces And Config (Current)
- Use portability tokens and deployment settings values:
  - SharePoint: `BGV_SPO_SITE_URL`, `BGV_LIST_CANDIDATES_ID`, `BGV_LIST_REQUESTS_ID`, `BGV_LIST_FORMDATA_ID`, `BGV_LIBRARY_RECORDS_ID`
  - Word template: `BGV_AUTH_TEMPLATE_SOURCE`, `BGV_AUTH_TEMPLATE_DRIVE_ID`, `BGV_AUTH_TEMPLATE_FILE_ID`
  - Forms: `BGV_FORM1_ID`, `BGV_FORM2_ID`
  - Notifications: `BGV_SHARED_MAILBOX_ADDRESS`, `BGV_INTERNAL_ALERT_TO`, `BGV_EMPLOYER_FALLBACK_TO`, `BGV_TEAMS_GROUP_ID`, `BGV_TEAMS_CHANNEL_ID`
  - Parser endpoint: `BGV_DOCX_PARSER_URI`
- Normalize connections in the green solution:
  - all SharePoint actions use one SharePoint connection reference
  - both Forms flows use one Forms connection reference
  - keep the existing Word Online connection reference, but bind it through deployment settings
- Add migration scripts under `scripts/active/`:
  - `bgv_migration_inventory.ps1`: source/target inventory, collision report, template metadata, open-vs-closed manifest
  - `bgv_ensure_target_schema.ps1`: idempotent create/verify of `BGV_Candidates`, `BGV_Requests`, `BGV_FormData`, `BGV Records`, and `Documents/BGV Templates`
  - `bgv_copy_site_data.ps1`: upsert rows/files by business keys, remap lookup item IDs, support `ClosedHistory` and `LegacyDrain` (`-Mode` required)
  - `bgv_build_deployment_settings.ps1`: generate local PAC deployment-settings JSON for test and prod
  - `bgv_validate_target_migration.ps1`: count parity, sample record checks, file-count checks, and portability guard execution
  - `check_bgv_portability.py`: fail if canonical flow JSON still contains old site/template/form/team/mailbox constants

## Step-By-Step Plan
1. Preflight and backup.
   - Verify `pac auth who` is `edwin.teo@dlresources.com.sg` before every PAC command.
   - Export a fresh production backup of the current blue `BGV_System`.
   - Run inventory against source and target:
     - `powershell -File .\scripts\active\bgv_migration_inventory.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
   - Review `out/migration/inventory.json`; stop if `TargetConflicts` is non-empty.
   - Verify the target site supports `anonymous` sharing links; if not, stop before refactoring because `BGV_0` currently depends on it.

2. Classify blue data for the two-wave history move.
   - Mark a case as `legacy-open` if `AuthorisationSigned != true` or any related request row has blank `ResponseReceivedAt`.
   - Mark all other cases as `closed-history`.
   - Use that manifest as the only source for Wave A and Wave B copying.

3. Create the green runtime assets with minimal UI-only work.
   - Keep the current Form 1 and Form 2 (no link changes); do not clone forms for production cutover.
   - Clone the 7 blue flows into a new solution `BGV_System_Green` so they receive new cloud-flow component IDs and can run in parallel with blue.
   - Create or bind any missing connection instances, and share green assets with `recruitment@dlresources.com.sg` if runtime validation needs that account.
   - Return to CLI immediately after cloning: export and unpack only the green solution; from this point, the repo tracks green as the canonical future-state source.

4. Refactor the green solution for portability.
   - Keep canonical flow JSON tokenized (`__BGV_*__`) and inject environment-specific values only in generated outputs (`*.token-values.json` and optional materialized solution folders).
   - Keep `BGV Records` and `Candidate Files/{CandidateID}/Authorization` unchanged so folder-path logic stays stable.
   - Update docs and add the portability guard so the old site URL and old template IDs cannot re-enter the canonical flow JSON.

5. Prepare the target site non-destructively.
   - Do not recreate the target site; only add BGV objects if absent.
   - Use schema script:
     - `powershell -File .\scripts\active\bgv_ensure_target_schema.ps1 -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
   - Script creates missing stores, validates base templates, and adds missing provisionable fields by source schema.
   - If an object name already exists with non-matching schema, stop instead of auto-merging.
   - Script ensures `BGV Templates` under the default documents library, uploads `AuthorizationLetter_Template.docx`, and writes Graph metadata to `out/migration/target_schema.json`.

6. Validate green in the separate test environment.
   - Generate test deployment settings:
     - `powershell -File .\scripts\active\bgv_build_deployment_settings.ps1 -EnvironmentName test -OutputDirectory .\out\deployment-settings -MaterializeTo .\out\materialized\bgv_green_test -TargetSchemaPath .\out\migration\target_schema.json`
   - Import green into the separate test environment and bind its connections.
   - Run smoke tests end-to-end on the target site with `MIGTEST-*` data only, then delete those test rows/files afterward.

7. Run Wave A before cutover.
   - Execute:
     - `powershell -File .\scripts\active\bgv_copy_site_data.ps1 -Mode ClosedHistory -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
   - Upsert `BGV_Candidates` by `CandidateID`, `BGV_Requests` by `RequestID`, and `BGV_FormData` by `RecordKey`.
   - Remap `CandidateItemID/Id`, `CandidateItemID`, and `RecordItemID` to the new target-site item IDs.
   - Copy only files belonging to `closed-history`; leave all `legacy-open` rows/files on blue.
   - Validate:
     - `powershell -File .\scripts\active\bgv_validate_target_migration.ps1 -Mode ClosedHistory -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`

8. Cut over new intake to green.
   - Freeze public intake briefly.
   - Export one more blue production backup.
   - Generate prod-green deployment settings using the target site, existing live forms, and the current production mailbox/team endpoints.
   - Pack/import from a materialized folder, not from tokenized canonical source.
   - Import green into production alongside blue; no Form URL change is required.
   - Keep existing forms active and route submissions through green target-bound flows; keep old site only for controlled legacy handling if needed.

9. Drain blue and retire it.
   - Monitor the `legacy-open` manifest daily until it reaches zero.
   - Run:
     - `powershell -File .\scripts\active\bgv_copy_site_data.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
     - `powershell -File .\scripts\active\bgv_validate_target_migration.ps1 -Mode LegacyDrain -SourceSiteUrl https://dlresourcespl88.sharepoint.com/sites/dlrespl -TargetSiteUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 -ClientId 3e59bbcc-3e14-4837-b6e0-0a1870286f31 -TenantId 38597470-4753-461a-837f-ad8c14860b22`
   - Validate final counts and samples, disable blue flows, archive the final blue backup, and retire only obsolete links (if any) that no longer match the approved existing Forms URLs.

## Test And Rollback
- Required smoke tests:
  - Form 1 submission creates candidate/request/formdata rows and an authorization DOCX in the target site.
  - Candidate signs through the anonymous link, `BGV_1` sets `AuthorisationSigned`, and `BGV_2` removes broad sharing.
  - `BGV_4` sends the employer email with the green Form 2 URL and the signed authorization attachment.
  - `BGV_5` updates target-site `BGV_Requests` and `BGV_FormData`.
  - Seeded reminder rows exercise `BGV_3` and `BGV_6` to test mailbox and Teams routing.
- Required validation gates:
  - no old site URL or old template/form/team/mailbox constants remain in canonical flow JSON
  - target/source row and file counts match the Wave A and Wave B manifests
  - 10 random `CandidateID` samples and 10 random `RequestID` samples match across source and target
- Rollback rule:
  - before green go-live, rollback is just “do not publish green”
  - after green go-live, rollback is “switch backend processing to blue flow set while keeping the same Forms links, disable green, export green delta for manual triage”; do not try to push partial green cases back into blue automatically

## Assumptions
- Production mailbox and Teams destinations stay the same; only test validation uses test-only endpoints.
- Azure Function behavior and the BGV business data model stay unchanged.
- Preserving SharePoint system fields like `Created`, `Modified`, `Author`, and `Editor` is out of scope; preserving BGV business fields, raw JSON, files, and key relationships is in scope.
