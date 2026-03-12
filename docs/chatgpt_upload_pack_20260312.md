# ChatGPT Upload Pack - BGV Migration (2026-03-12)

## 1) Objective
Migrate BGV automation from source SharePoint site to target SharePoint site using blue/green approach, preserving history and relationships.

## 2) Environment
- Tenant: D L RESOURCES PTE LTD
- Tenant ID: `38597470-4753-461a-837f-ad8c14860b22`
- Power Platform production env URL: `https://orgde64dc49.crm5.dynamics.com/`
- Flow environment name: `Default-38597470-4753-461a-837f-ad8c14860b22`
- Source SharePoint site (blue): `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
- Target SharePoint site (green): `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`

## 3) What is completed
- Migration inventory generated.
- Target schema generated with template metadata.
- Data migration completed and validated:
  - `BGV_Candidates`: 5
  - `BGV_Requests`: 8
  - `BGV_FormData`: 8
  - `BGV Records` files parity validated (5 files copied; folders also present).
- Legacy lookup/remap issues fixed:
  - `BGV_Requests.CandidateItemID` lookup binding repaired to target list.
  - `BGV_FormData` remap for `CandidateItemID`/`RecordItemID` fixed.
- Final deployment settings generated for both test/prod.
- Blue production flows (`BGV_0`..`BGV_6`) were disabled.
- Final blue backup archived.

## 4) Current production truth (important)
From `out/migration/production_flow_runtime_status.json`:
- All `BGV_*` flows are currently `Stopped`.
- Current deployed flow definitions still reference source site (`dlrespl`).
- No deployed production flow currently references target site (`DLRRecruitmentOps570`).

Interpretation:
- SharePoint data migration is done.
- Production green runtime is NOT live yet.
- Production cutover still requires green import/bind/enable.

## 5) Key artifacts
- Inventory: `out/migration/inventory.json`
- Closed history copy/validate:
  - `out/migration/copy_closedhistory.json`
  - `out/migration/validate_closedhistory.json`
- Legacy drain copy/validate:
  - `out/migration/copy_legacydrain.json`
  - `out/migration/validate_legacydrain.json`
- Target schema: `out/migration/target_schema.json`
- Final deployment settings:
  - `out/deployment-settings/final/test.pac.settings.json`
  - `out/deployment-settings/final/test.token-values.json`
  - `out/deployment-settings/final/prod.pac.settings.json`
  - `out/deployment-settings/final/prod.token-values.json`
- Materialized solution folders:
  - `out/materialized/bgv_green_test_final`
  - `out/materialized/bgv_green_prod_final`
- Blue closeout report: `out/migration/closeout_report.json`
- Production flow runtime status: `out/migration/production_flow_runtime_status.json`
- Final blue backup:
  - `artifacts/exports/BGV_System_blue_final_backup_20260312_022951.zip`

## 6) Remaining manual/operational tasks
1. Production green go-live:
- Import green materialized solution into production.
- Bind production connections.
- Enable green `BGV_0`..`BGV_6`.
- Verify they reference target site and process new intake end-to-end.

2. Forms/public link retirement:
- Disable/close old blue Microsoft Forms.
- Retire old intake links from Teams/email/intranet/docs/QR/bookmarks.
- Publish new green intake links only.

## 7) Ask for ChatGPT
Please provide a strict runbook for:
1. Production green import/bind/enable with verification evidence checkpoints.
2. Manual Forms retirement and communication cleanup checklist.
3. Rollback steps if green intake fails after enablement.

Please keep the runbook operational, step-by-step, and include what to capture as proof at each stage.
