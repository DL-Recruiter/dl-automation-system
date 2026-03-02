# Project Progress

Log each session with:
- Current status
- Completed tasks
- Validation commands run
- Next actions and blockers

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
