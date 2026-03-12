# Flow and Connector Architecture

## Runtime and CLI Baseline
- Signed-in profile: `recruitment@dlresources.com.sg`
- Environment URL: `https://orgde64dc49.crm5.dynamics.com/`
- CLI assumption: `pac`, `az`, and `func` are installed and authenticated already.
- Agent rule: do not install or reauthenticate these CLIs unless the user explicitly asks.

## Authentication Contexts (Important)
- `pac` auth context:
  - used for Power Platform solution operations (`pac solution export/pack/import`, connector/Dataverse tasks).
- Power Automate runtime connection context:
  - flow actions (for example SharePoint actions) run under connection references such as `shared_sharepointonline`.
- PnP.PowerShell context:
  - used only for direct SharePoint list/site administration from terminal.
  - interactive app registration baseline in this tenant:
    - `Register-PnPEntraIDAppForInteractiveLogin`
    - app display name `BGV-PnP-Automation`
    - client id `3e59bbcc-3e14-4837-b6e0-0a1870286f31`

## Flows

### BGV SharePoint Components (Live)
- `BGV_Candidates` (list id `7b78dcaf-8744-478b-a40f-633ed7becff3`):
  - Candidate-level progress tracker for Form 1 and authorization-signature lifecycle.
- `BGV_Requests` (list id `4acba8e0-46aa-4007-b752-b4aa88fee7f7`):
  - Employer-request tracker for Form 2 dispatch/reminders/outcome.
- `BGV_FormData` (list id `f5248a99-fdf1-4660-946a-d54e00575a40`):
  - Master data list for normalized Form 1 + Form 2 fields and raw form payload snapshots.
- `BGV Records` (document library id `d411563f-2b1c-4fa5-90fc-ecc5f50941a1`):
  - Candidate files, including authorization documents used in outbound employer requests.

### BGV Green Portability Layer
- Canonical green-source flow files remain under:
  - `flows/power-automate/unpacked/Workflows/`
- Those canonical JSON files are now tokenized with `__BGV_*__` markers for:
  - SharePoint site URL
  - target list/library IDs
  - Word template `source` / `drive` / `file`
  - Form 1 / Form 2 IDs
  - mailbox and Teams routing targets
  - DOCX parser endpoint URI (includes function auth query token in deployment values only)
- Portability guard:
  - `scripts/active/check_bgv_portability.py`
  - fails if old source-site literals or old production template/form/team/mailbox constants re-enter canonical flow JSON
- Materialization step:
  - `scripts/active/bgv_build_deployment_settings.ps1`
  - generates:
    - `out/deployment-settings/<env>.pac.settings.json`
    - `out/deployment-settings/<env>.token-values.json`
    - optional materialized packable solution folder via `-MaterializeTo`
- Important rule:
  - do not pack the raw tokenized `flows/power-automate/unpacked/` folder for green deployment
  - pack the materialized folder produced by `bgv_build_deployment_settings.ps1`

### Normalized Green Connection References
- SharePoint:
  - `cr94d_sharedsharepointonline_96d5d`
- Microsoft Forms:
  - `cr94d_sharedmicrosoftforms_a2caf`
- Office 365 Outlook:
  - `cr94d_sharedoffice365_bdd97`
- Microsoft Teams:
  - `cr94d_sharedteams_4466d`
- Word Online (Business):
  - `new_sharedwordonlinebusiness_2ff9a`

This repo state removes the extra duplicate SharePoint and Forms
connection references so the future green solution can bind one
connection reference per connector type during deployment.

### SharePoint Migration Automation Scripts
- `scripts/active/bgv_migration_inventory.ps1`
  - inventories source/target stores, classifies `legacy-open` vs
    `closed-history`, reports target collisions, and checks target-site
    sharing capability through CLI for Microsoft 365
- `scripts/active/bgv_ensure_target_schema.ps1`
  - idempotently creates/verifies the target `BGV_Candidates`,
    `BGV_Requests`, `BGV_FormData`, `BGV Records`, and `BGV Templates`
    locations and captures uploaded template Graph metadata
- `scripts/active/bgv_copy_site_data.ps1`
  - upserts rows by `CandidateID`, `RequestID`, and `RecordKey`
  - remaps lookup item IDs after target rows are created
  - copies candidate files in `BGV Records`
- `scripts/active/bgv_validate_target_migration.ps1`
  - checks row/file counts, compares random samples, and reruns the
    portability guard before cutover or retirement of blue

### main
- Definition file: `flows/main.flow.json`
- Connector use:
  - `shared_sharepointonline` (API name: `shared_sharepointonline`, connection ID: `__REPLACE_WITH_CONNECTION_ID__`)
- Intended purpose:
  - Reads/writes SharePoint resources and orchestrates core automation steps.

### FlowRunLogs exporter
- Definition file: `flows/flowrunlogs-exporter.flow.json`
- Connector use:
  - `shared_flowrunops` (API name: `shared_flowrunops`, connection ID: `__REPLACE_WITH_CONNECTION_ID__`)
  - `shared_sharepointonline` (API name: `shared_sharepointonline`, connection ID: `__REPLACE_WITH_CONNECTION_ID__`)
- Intended purpose:
  - Exports flow run logs and persists output through SharePoint integration.

### BGV_4 employer verification link prefill
- Canonical flow file:
  - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Current behavior:
  - Reads matching `BGV_FormData` row by `RequestID` and uses it as prefill source (with fallback to `BGV_Candidates`/`BGV_Requests` values if missing).
  - `FinalVerificationLink` builds the second Microsoft Form URL using URL-encoded prefill query parameters:
    - `r4930fc603c0f4cada09832be79f2a76f` -> candidate full name (`BGV_FormData.F1_CandidateFullName`)
    - `r27b6bdb850dd48339dc05df11d485470` -> candidate NRIC (`BGV_FormData.F1_IDNumberNRIC`)
    - `r0c342001cdd8463181c36dba2a8933ad` -> candidate passport (`BGV_FormData.F1_IDNumberPassport`)
    - `rd745d133eb7f4611b59ea051f980f97a` -> request ID (`BGV_Requests.RequestID`)
    - `rccaf3632669648baaa335c12d4ea40bf` -> declared company name (`BGV_FormData.F1_EmployerName`)
    - `rcf35c7cc008e472f9d0b84bde67cc1ff` -> declared company UEN (`BGV_FormData.F1_EmployerUEN`)
    - `r19aae6e8163d4aaeb8a3f3f2d5329be2` -> declared company address (`BGV_FormData.F1_EmployerAddress`)
    - `r0bef44c0d22d493f95a33484875b951e` -> declared employment period (`start to end` when both dates exist; otherwise single available date)
    - `ra6ab2e26d2d84a92b33148fc4694773a` -> declared last drawn salary (`BGV_FormData.F1_LastDrawnSalary`)
    - `r49ca8a655f5e4bcba0e8f75d4475ad77` -> declared last position held (`BGV_FormData.F1_JobTitle`)
  - The employer email body also includes declared company details for operator visibility.
  - In the current HR Form 2 layout, questions explicitly labeled `(Declared By Candidate)` are the intended prefill targets in `BGV_4`.
  - `r513ad5ab3a14453286bdb910820985ec` (`Q11` reason for leaving) is not one of those current prefill targets. It is an employer-entered response field, so `BGV_4` intentionally leaves it blank and `BGV_5` stores the submitted answer later.
- Important limitation:
  - Microsoft Forms static text placeholders (for example `{{Employer_Name}}`) are not dynamically replaced by Power Automate.
  - Dynamic values must come through actual form question prefill fields (the `r...` query parameters above).

### BGV_FormData Wiring (Flows 0 / 4 / 5)
- `BGV_0_CandidateDeclaration`:
  - Creates one `BGV_FormData` row per employer segment (`EMP1`/`EMP2`/`EMP3`) whenever a new request row is created.
  - Writes `RecordKey`, `CandidateID`, `RequestID`, `EmployerSlot`, candidate basic fields, normalized employer fields (`F1_EmployerName/UEN/Address/PostalCode`, `F1_JobTitle`, `F1_LastDrawnSalary`, `F1_EmploymentStartDate`, `F1_EmploymentEndDate`, `F1_HRContactName`, `F1_HREmail`, `F1_HRMobile`), and `Form1RawJson`.
- `BGV_4_SendToEmployer_Clean`:
  - Reads `BGV_FormData` by `RequestID` for prefill generation.
- `BGV_5_Response1`:
  - On employer form submission, updates matching `BGV_FormData` row (by `RequestID`) with normalized Form 2 fields and `Form2RawJson`.

## Connectors

### shared_flowrunops
- Definition file: `connectors/shared_flowrunops.powerplatform.json`
- API name: `shared_flowrunops`
- Connection ID: `__REPLACE_WITH_CONNECTION_ID__`
- Used by:
  - Flow: `FlowRunLogs exporter`
  - Code app: optional non-tabular data source via PAC CLI

### new_flowrunops (Dataverse custom connector)
- Definition files:
  - `connectors/new_flowrunops.connector.xml`
  - `connectors/new_flowrunops.oauth.parameters.json`
- API name: `new_flowrunops`
- Connection ID: `__REPLACE_WITH_CONNECTION_ID__`
- Used by:
  - Code app integration (custom connector data source)

## Azure Function Integration
- Function endpoint variable: `FUNCTION_ENDPOINT_URL`
- Function auth variable: `FUNCTION_KEY`
- Request requirement:
  - Send `FUNCTION_KEY` as `x-functions-key` header when calling the API endpoint.
- Security requirement:
  - Real function key must be in local `.env` only; never commit credentials.

## PAC CLI Guidance
Use PAC CLI for connection and data-source automation rather than manual UI steps.

- List connections and collect IDs/API names:
```powershell
pac connection list
```

- Add non-tabular connector data source to a code app:
```powershell
pac code add-data-source -a <apiName> -c <connectionId>
```

- Tabular data sources (for example Dataverse tables) require table metadata in addition to connection:
  - API name
  - Connection ID
  - Table ID
  - Dataset name

Connection IDs can be collected from:
- `pac connection list`
- Power Apps portal connection details

## Export Reproducibility Notes
The files in `flows/` and `connectors/` are currently placeholders in this repository snapshot and must be replaced with authenticated exports from the target tenant/environment before release.

### Importing Authenticated Exports into Repo Paths
After exporting flow definitions from Power Automate (solution/logicapp JSON), copy them into repository-standard names with:
```powershell
powershell -File scripts/active/import_flow_exports.ps1 `
  -MainFlowExportPath <path-to-main-flow-export.json> `
  -FlowRunLogsExporterPath <path-to-flowrunlogs-exporter-export.json>
```

## Flow Verification Script
- Script path: `scripts/active/verify_flow_runs.py`
- Purpose:
  - Request OAuth2 token using tenant/client credentials from environment variables.
  - Call Flow run-history API and normalize output fields.
  - Print run metadata (`name`, `status`, `startTime`, `endTime`, trigger/output links) as JSON.

### Default ARM Endpoint Mode
When `FLOW_VERIFY_RUNS_URL` is empty, the script builds:
`https://management.azure.com/providers/Microsoft.ProcessSimple/environments/{environmentId}/flows/{flowId}/runs?api-version=2016-11-01`

### Connector Endpoint Override Mode
When `FLOW_VERIFY_RUNS_URL` is set, the script calls that URL directly instead of composing the ARM URL. Use this for FlowRunOps connector test endpoints.

### Example Run
```powershell
python scripts/active/verify_flow_runs.py
```

## Pull All Canonical Flow Runs (VS Code Friendly)
- Script path: `scripts/active/pull_all_flow_runs.py`
- Purpose:
  - Discover canonical flow IDs from `flows/power-automate/unpacked/Workflows/`.
  - Pull run history for each canonical flow automatically.
  - Save a combined report to `out/flow_run_history_latest.json` by default.

### Optional Environment Variables
- `FLOW_VERIFY_CANONICAL_DIR` (default: `flows/power-automate/unpacked/Workflows`)
- `FLOW_VERIFY_REPORT_PATH` (default: `out/flow_run_history_latest.json`)
- `FLOW_VERIFY_TOP` (optional integer run limit per flow, for example `10`)

### Example Run (All 7 Flows)
```powershell
py scripts/active/pull_all_flow_runs.py
```
