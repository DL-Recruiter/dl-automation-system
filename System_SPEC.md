# System_SPEC - System Specification Template

<!-- This template defines the source-of-truth document for this automation project. -->

## 1. System Purpose & Scope
The **DL Resources Automation** system automates business workflows by coordinating scripts, optional serverless functions, and Power Automate flows.
Primary goals:
- Reduce manual operational steps.
- Enforce consistent processing rules.
- Produce auditable outputs.

## 2. Terminology
| Term | Definition |
| --- | --- |
| Automation Run | A single execution of a workflow. |
| Source System | Upstream system that provides input data. |
| Output Artifact | Generated log/report/result file stored in `out/`. |

## 3. API Contract
If APIs are exposed or consumed, document each endpoint with:
- Name
- Purpose
- HTTP method and path
- Request parameters
- Response schema
- Authentication expectations

### ParseAuthorizationControls
Purpose:
- Parses a candidate authorization DOCX and returns checkbox-based authorization status used by the BGV flows.
- Adds additive Level A drawing-detection metadata based on Open XML package inspection.

HTTP method and path:
- `GET /api/ParseAuthorizationControls`
- `POST /api/ParseAuthorizationControls`

Authentication:
- Azure Function endpoint protected by `AuthorizationLevel.Function`.
- Callers must send the function key via `x-functions-key`.

**Request Fields (`POST`):**
| Field | Description | Type | Required? |
| --- | --- | --- | --- |
| `fileName` | Source DOCX filename for logging/traceability. | string | No |
| `docxBase64` | Base64-encoded DOCX payload to parse. | string | Yes |

**GET health response (`200 OK`):**
```json
{
  "status": "ok",
  "message": "Use POST with JSON { fileName, docxBase64 }."
}
```

**Response (200 OK):**
```json
{
  "fileName": "candidate.docx",
  "signedYes": true,
  "signedNo": false,
  "controlsFound": [
    {
      "tag": "SignedYes",
      "title": "SignedYes",
      "isChecked": true
    }
  ],
  "note": "Best practice: use SignedYes for the consent checkbox tag/title. CandidateAuthorisation remains supported for compatibility.",
  "drawingDetection": {
    "enabled": true,
    "signatureDetected": false,
    "level": "A",
    "findings": []
  }
}
```

**Response Fields (`200 OK`):**
| Field | Description | Type | Notes |
| --- | --- | --- | --- |
| `fileName` | Echo of the provided filename. | string or null | Preserved for Power Automate compatibility. |
| `signedYes` | Summary of current SignedYes-compatible checkbox matches. | boolean or null | Current checkbox contract remains authoritative for flow decisions. |
| `signedNo` | Summary of current SignedNo checkbox matches. | boolean or null | Preserved current null/false semantics. |
| `controlsFound` | Parsed checkbox content controls from the current DOCX parsing scope. | array | Exposed to Power Automate for downstream logic/debugging. |
| `note` | Parser guidance string. | string | Informational only. |
| `drawingDetection.enabled` | Whether Level A drawing detection ran. | boolean | Currently `true` on successful detection pass, `false` on fallback. |
| `drawingDetection.signatureDetected` | Whether Level A detected drawing-like signature content anywhere in the DOCX package. | boolean or null | `null` when detection is disabled/fell back. |
| `drawingDetection.level` | Detection level identifier. | string or null | Currently `\"A\"` when detection runs, otherwise `null`. |
| `drawingDetection.findings[]` | Structured additive findings from Level A package inspection. | array | Each finding includes `kind`, `partUri`, and `detail`. |

**Level A drawing detection scope and limitations:**
- Level A is additive only and does not change checkbox detection behavior.
- Detection is based on Open XML / DOCX package inspection only.
- It returns `signatureDetected = true` when the DOCX package contains any of:
  - ink-related content
  - freeform or scribble-like drawing geometry markers
  - drawing canvas or grouped drawing content
- It does not perform Word COM automation, raster image analysis, or visual signature recognition.

**Fallback behavior on drawing-detection failure:**
- If Level A drawing detection throws or cannot complete, the function preserves the existing checkbox response behavior.
- In fallback mode, `drawingDetection` returns the disabled placeholder:
```json
{
  "enabled": false,
  "signatureDetected": null,
  "level": null,
  "findings": []
}
```

Governance:
- Existing consumers may ignore `drawingDetection`; the checkbox contract remains authoritative for current flow behavior.

**Error Codes:**
- `400 Bad Request` - invalid input.
- `401 Unauthorized` - invalid or missing function key.
- `413 Request Entity Too Large` - request body or decoded DOCX exceeds enforced limits.
- `500 Internal Server Error` - unexpected failure.

## 4. Data Models & Structures
Document key data shapes used by scripts, functions, and flows:
- Input payload schema
- Internal normalized schema
- Output artifact schema

### BGV SharePoint Data Model (Current)
- `BGV_Candidates` (tracking list):
  - One row per candidate declaration submission.
  - Holds candidate-level details and authorization progress fields (`Status`, `AuthorizationLink`, `AuthorisationSigned`, reminder timestamps).
- `BGV_Requests` (tracking list; internal list id used in flows: `4acba8e0-46aa-4007-b752-b4aa88fee7f7`):
  - One row per employer request (`EMP1`/`EMP2`/`EMP3`).
  - Holds operational status fields for employer outreach and completion (`VerificationStatus`, `HRRequestSentAt`, reminders, `Outcome`, `Severity`, `Notes`).
- `BGV_FormData` (master form-data list; list id `f5248a99-fdf1-4660-946a-d54e00575a40`):
  - One row per employer segment of Form 1 (EMP1/EMP2/EMP3).
  - Stores normalized Form 1 and Form 2 fields, plus raw JSON snapshots (`Form1RawJson`, `Form2RawJson`).
  - Key fields: `RecordKey` (unique), `CandidateID`, `RequestID`.
- `BGV Records` (document library):
  - Stores candidate folders and signed authorization documents used by the BGV flows.

Key relationships:
- `CandidateID`: links `BGV_Candidates` <-> `BGV_Requests` <-> `BGV_FormData` <-> candidate folder path in `BGV Records`.
- `RequestID`: links employer verification cycle between `BGV_Requests` and `BGV_FormData`.

### BGV SharePoint Site Migration Portability Contract
- Blue/source site:
  - `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
- Green/target site:
  - `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`
- Canonical cloud-flow JSON under `flows/power-automate/unpacked/Workflows/` is now portability-tokenized with `__BGV_*__` markers rather than hardcoded SharePoint, template, Forms, Teams, and mailbox identifiers.
- Token categories currently covered:
  - SharePoint site URL
  - `BGV_Candidates`, `BGV_Requests`, `BGV_FormData`, and `BGV Records` IDs
  - Word template `source`, `drive`, and `file` IDs
  - Form 1 / Form 2 IDs
  - shared mailbox, internal alert, employer fallback, Teams group, and Teams channel targets
  - DOCX parser endpoint URI token (`BGV_DOCX_PARSER_URI`)
- Canonical tokenized JSON is the reviewable source of truth, but it is not the direct deployment artifact for the green site.
- `scripts/active/bgv_build_deployment_settings.ps1` is responsible for producing a materialized deployment folder by combining:
  - connection-reference settings from PAC CLI
  - token values from deployment templates
  - optional target schema output from `scripts/active/bgv_ensure_target_schema.ps1`
  - optional `BGV_*` shell environment variable overrides
- SharePoint data migration business keys:
  - upsert `BGV_Candidates` by `CandidateID`
  - upsert `BGV_Requests` by `RequestID`
  - upsert `BGV_FormData` by `RecordKey`
  - remap lookup item IDs after the target-site rows are created
- Migration classification contract:
  - `legacy-open` if `AuthorisationSigned != true` or any related request has blank `ResponseReceivedAt`
  - `closed-history` for all other candidate cases

## 5. Business Rules
- Validate all required inputs before processing.
- Apply deterministic transformations.
- Fail fast on malformed data with clear error messages.
- Log run metadata and outcomes in auditable form.

When rules change, perform an impact sweep across scripts, tests, and docs in the same change.

## 6. Security & Access Control
- Never hardcode secrets or tokens.
- Use environment variables for credentials and endpoints.
- Keep `.env` out of version control.
- Use HTTPS for external calls where applicable.
- Azure Function keys must be passed via `x-functions-key` and stored in local `.env` only.

## 7. Runtime Environment
| Item | Value |
| --- | --- |
| Admin/ALM profile | `edwin.teo@dlresources.com.sg` |
| Operations/collaborator profile | `recruitment@dlresources.com.sg` |
| Power Platform environment URL | `https://orgde64dc49.crm5.dynamics.com/` |
| Azure tenant | `__REPLACE_WITH_AZURE_TENANT_ID_OR_NAME__` |
| Azure subscription | `__REPLACE_WITH_AZURE_SUBSCRIPTION_ID_OR_NAME__` |

Runtime tooling baseline:
- Power Platform CLI (`pac`) is expected to already be installed and authenticated.
- Azure CLI (`az`) is expected to already be installed and authenticated.
- Azure Functions Core Tools (`func`) is expected to already be installed and authenticated.
- CLI for Microsoft 365 (`m365`) is expected to already be installed and authenticated for SharePoint inventory/sharing checks.
- Microsoft Graph PowerShell is expected to already be installed and authenticated for template metadata capture.
- PnP.PowerShell is used for SharePoint list/schema administration.
- Agents must not reauthenticate or install these tools unless explicitly requested by the user.

Authentication context separation baseline:
- `pac` auth: solution/flow/connector packaging and Dataverse operations.
- Power Automate runtime connector auth: flow connection references (for example `shared_sharepointonline`).
- PnP.PowerShell auth: direct SharePoint list/site administration via interactive app login.

PnP interactive app login baseline:
- Tenant app registration flow used: `Register-PnPEntraIDAppForInteractiveLogin`.
- Current tenant app display name: `BGV-PnP-Automation`.
- Current tenant app (client) id: `3e59bbcc-3e14-4837-b6e0-0a1870286f31`.
- Do not store app secrets in repo; keep local-only in `.env` if required.

Connection/data-source automation baseline:
- Use CLI-first automation. Prefer `pac connection list` to discover connector API names and connection IDs.
- For adding non-tabular connector sources to a code app, use `pac code add-data-source -a <apiName> -c <connectionId>`.
- For SharePoint/custom connector integration, always provide both API name (example: `shared_sharepointonline`) and the target connection ID.
- Capture connection IDs via `pac connection list` or the Power Apps portal before wiring flows or code apps.

## 8. Environment Variables
| Variable | Purpose | Required? | Default/Example |
| --- | --- | --- | --- |
| `API_URL` | Base URL for upstream/downstream API | No | `https://example.local` |
| `API_ACCESS_TOKEN` | Bearer token or API secret | No | *(set in `.env` only)* |
| `CUSTOM_SETTING` | Optional behavior flag | No | `20` |
| `POWER_PLATFORM_ENV_URL` | Dataverse/Power Platform environment URL | Yes | `https://orgde64dc49.crm5.dynamics.com/` |
| `SHAREPOINT_SITE_URL` | SharePoint site used by `shared_sharepointonline` | Yes | `https://contoso.sharepoint.com/sites/example` |
| `PNP_CLIENT_ID` | Client ID for PnP interactive app login (`Connect-PnPOnline`) | Yes (for PnP list admin scripts) | `__REPLACE_WITH_PNP_ENTRA_APP_CLIENT_ID__` |
| `PNP_TENANT_ID` | Azure tenant ID used by PnP interactive app login | Yes (for PnP list admin scripts) | `__REPLACE_WITH_AZURE_TENANT_ID__` |
| `DATAVERSE_INSTANCE_URL` | Dataverse instance URL for connector/app configuration | Yes | `https://orgde64dc49.crm5.dynamics.com/` |
| `FUNCTION_ENDPOINT_URL` | Azure Function endpoint consumed by flow/app logic | Yes | `https://<functionapp>.azurewebsites.net/api/<endpoint>` |
| `FUNCTION_KEY` | Value sent as `x-functions-key` when calling Azure Function API endpoint | Yes | `__REPLACE_WITH_FUNCTION_KEY__` |
| `BGV_SOURCE_SPO_SITE_URL` | Blue/source SharePoint site used by migration inventory/copy scripts | Yes (for migration scripts) | `https://dlresourcespl88.sharepoint.com/sites/dlrespl` |
| `BGV_TARGET_SPO_SITE_URL` | Green/target SharePoint site used by migration inventory/copy scripts | Yes (for migration scripts) | `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570` |
| `BGV_SPO_SITE_URL` | Materialized SharePoint site token for green flow deployment | Yes (for green materialization) | `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570` |
| `BGV_LIST_CANDIDATES_ID` | Target `BGV_Candidates` list ID token | Yes (for green materialization) | `__REPLACE_WITH_TARGET_BGV_CANDIDATES_LIST_ID__` |
| `BGV_LIST_REQUESTS_ID` | Target `BGV_Requests` list ID token | Yes (for green materialization) | `__REPLACE_WITH_TARGET_BGV_REQUESTS_LIST_ID__` |
| `BGV_LIST_FORMDATA_ID` | Target `BGV_FormData` list ID token | Yes (for green materialization) | `__REPLACE_WITH_TARGET_BGV_FORMDATA_LIST_ID__` |
| `BGV_LIBRARY_RECORDS_ID` | Target `BGV Records` library ID token | Yes (for green materialization) | `__REPLACE_WITH_TARGET_BGV_RECORDS_LIBRARY_ID__` |
| `BGV_AUTH_TEMPLATE_SOURCE` | Word template `source` token used by `BGV_0` | Yes (for green materialization) | `__REPLACE_WITH_TARGET_TEMPLATE_SOURCE__` |
| `BGV_AUTH_TEMPLATE_DRIVE_ID` | Word template drive ID token used by `BGV_0` | Yes (for green materialization) | `__REPLACE_WITH_TARGET_TEMPLATE_DRIVE_ID__` |
| `BGV_AUTH_TEMPLATE_FILE_ID` | Word template file ID token used by `BGV_0` | Yes (for green materialization) | `__REPLACE_WITH_TARGET_TEMPLATE_FILE_ID__` |
| `BGV_FORM1_ID` | Green Microsoft Form 1 ID token | Yes (for green materialization) | `__REPLACE_WITH_GREEN_FORM1_ID__` |
| `BGV_FORM2_ID` | Green Microsoft Form 2 ID token | Yes (for green materialization) | `__REPLACE_WITH_GREEN_FORM2_ID__` |
| `BGV_SHARED_MAILBOX_ADDRESS` | Shared mailbox token used by alert/email actions | Yes (for green materialization) | `__REPLACE_WITH_SHARED_MAILBOX_ADDRESS__` |
| `BGV_INTERNAL_ALERT_TO` | Internal alert recipient token | Yes (for green materialization) | `__REPLACE_WITH_INTERNAL_ALERT_TO_ADDRESS__` |
| `BGV_EMPLOYER_FALLBACK_TO` | Employer fallback mailbox token | Yes (for green materialization) | `__REPLACE_WITH_EMPLOYER_FALLBACK_ADDRESS__` |
| `BGV_TEAMS_GROUP_ID` | Teams group token used by reminder/escalation flows | Yes (for green materialization) | `__REPLACE_WITH_TEAMS_GROUP_ID__` |
| `BGV_TEAMS_CHANNEL_ID` | Teams channel token used by reminder/escalation flows | Yes (for green materialization) | `__REPLACE_WITH_TEAMS_CHANNEL_ID__` |
| `BGV_DOCX_PARSER_URI` | Parser endpoint URI token used by `BGV_1` HTTP action | Yes (for green materialization) | `https://<functionapp>.azurewebsites.net/api/parseauthorizationcontrols?code=<function-key>` |
| `BGV_CONN_MICROSOFTFORMS_ID` | Optional override for Forms connection ID when generating PAC settings | No | `shared-microsoftform-<id>` |
| `BGV_CONN_OFFICE365_ID` | Optional override for Office 365 connection ID when generating PAC settings | No | `<office365-connection-id>` |
| `BGV_CONN_SHAREPOINT_ID` | Optional override for SharePoint connection ID when generating PAC settings | No | `<sharepoint-connection-id>` |
| `BGV_CONN_TEAMS_ID` | Optional override for Teams connection ID when generating PAC settings | No | `shared-teams-<id>` |
| `BGV_CONN_WORDONLINEBUSINESS_ID` | Optional override for Word Online (Business) connection ID when generating PAC settings | No | `shared-wordonlinebus-<id>` |
| `FLOW_VERIFY_TENANT_ID` | Azure AD tenant for Flow Management API OAuth token request | Yes | `__REPLACE_WITH_AZURE_TENANT_ID__` |
| `FLOW_VERIFY_CLIENT_ID` | OAuth client ID for flow verification app registration | Yes | `__REPLACE_WITH_APP_REGISTRATION_CLIENT_ID__` |
| `FLOW_VERIFY_CLIENT_SECRET` | OAuth client secret for flow verification app registration | Yes | *(set in `.env` only)* |
| `FLOW_VERIFY_ENVIRONMENT_ID` | Power Platform environment ID for ARM run-history endpoint | Yes (if `FLOW_VERIFY_RUNS_URL` is empty) | `__REPLACE_WITH_POWER_PLATFORM_ENVIRONMENT_ID__` |
| `FLOW_VERIFY_FLOW_ID` | Power Automate flow ID for ARM run-history endpoint | Yes (if `FLOW_VERIFY_RUNS_URL` is empty) | `__REPLACE_WITH_FLOW_ID__` |
| `FLOW_VERIFY_SCOPE` | OAuth scope used to request access token | No | `https://management.azure.com/.default` |
| `FLOW_VERIFY_BASE_URL` | Base URL for ARM Flow Management API | No | `https://management.azure.com` |
| `FLOW_VERIFY_API_VERSION` | API version for run-history endpoint | No | `2016-11-01` |
| `FLOW_VERIFY_RUNS_URL` | Optional full runs endpoint URL (for connector endpoint override) | No | *(leave empty to use ARM URL composition)* |

Maintain `.env.example` with placeholder values only.

## 9. Deployment & Hosting
Document runtime/deployment model when finalized:
- Local scripts and docs.
- Serverless function integration (`functions/`).
- Power Automate exports (`flows/`) and connector definitions (`connectors/`).

Current BGV migration deployment model:
- Keep canonical unpacked flow JSON tokenized in source control.
- Use `scripts/active/bgv_build_deployment_settings.ps1` plus `flows/power-automate/deployment-settings/*.settings.template.json` to generate deployment inputs.
- Pack/import the materialized green folder, not the raw tokenized canonical folder.
- Use `scripts/active/bgv_migration_inventory.ps1`, `scripts/active/bgv_ensure_target_schema.ps1`, `scripts/active/bgv_copy_site_data.ps1`, and `scripts/active/bgv_validate_target_migration.ps1` for SharePoint-side migration execution and validation.

## 10. Error Handling & Logging
- Use structured, actionable error messages.
- Log at appropriate levels (`INFO`, `WARNING`, `ERROR`).
- Write runtime artifacts to `out/` for debugging/audit.

## 11. Non-Functional Requirements
- Reliability: deterministic processing and retry-safe behavior.
- Maintainability: clear modules and tests under `tests/`.
- Traceability: all behavior changes reflected in this spec and progress log.

## 12. Change Management
This file is the single source of truth for system behavior.
1. Update this spec first for behavior/contract changes.
2. Perform an impact sweep across scripts, tests, and docs.
3. Update related files in the same task.
4. Record changes and validation commands in `docs/progress.md`.
5. If a related file is intentionally unchanged, explain why in the change report.

## 13. References
- `AGENTS.md`
- `CODEX_PLAYBOOK.md`
- `docs/progress.md`
- `docs/architecture_flows.md`
