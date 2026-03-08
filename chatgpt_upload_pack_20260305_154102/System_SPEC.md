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

### ENDPOINT_NAME
| Field | Description | Type | Required? |
| --- | --- | --- | --- |
| param_1 | Placeholder request field | string | Yes |
| param_2 | Optional request field | integer | No |

**Response (200 OK):**
```json
{
  "field_1": "...",
  "field_2": []
}
```

**Error Codes:**
- `400 Bad Request` - invalid input.
- `401 Unauthorized` - invalid or missing auth.
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
| Signed-in profile | `recruitment@dlresources.com.sg` |
| Power Platform environment URL | `https://orgde64dc49.crm5.dynamics.com/` |
| Azure tenant | `__REPLACE_WITH_AZURE_TENANT_ID_OR_NAME__` |
| Azure subscription | `__REPLACE_WITH_AZURE_SUBSCRIPTION_ID_OR_NAME__` |

Runtime tooling baseline:
- Power Platform CLI (`pac`) is expected to already be installed and authenticated.
- Azure CLI (`az`) is expected to already be installed and authenticated.
- Azure Functions Core Tools (`func`) is expected to already be installed and authenticated.
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
