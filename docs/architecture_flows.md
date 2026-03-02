# Flow and Connector Architecture

## Runtime and CLI Baseline
- Signed-in profile: `recruitment@dlresources.com.sg`
- Environment URL: `https://orgde64dc49.crm5.dynamics.com/`
- CLI assumption: `pac`, `az`, and `func` are installed and authenticated already.
- Agent rule: do not install or reauthenticate these CLIs unless the user explicitly asks.

## Flows

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
