# File Index

## Folders
- `.github/` - GitHub workflows and repository automation metadata.
- `.venv/` - Local Python virtual environment directory.
- `connectors/` - Power Platform and Dataverse custom connector definition exports.
- `docs/` - Project documentation, progress logs, and repository indexes.
- `DRAFT/` - Protected archive area; do not modify unless explicitly requested.
- `flows/` - Power Automate flow exports and related metadata.
- `functions/` - Optional serverless function entry points.
- `out/` - Runtime output and debug artifacts.
- `scripts/` - Script workspace root.
- `scripts/active/` - In-progress scripts under active development.
- `scripts/legacy/` - Archived or superseded scripts kept for reference.
- `shared/` - Reusable shared modules and helpers.
- `tests/` - Automated tests and test fixtures.

## Files
- `.env.example` - Placeholder environment variable template (no real secrets).
- `.gitignore` - Ignore rules for secrets, virtual env, and generated outputs.
- `AGENTS.md` - Agent operating constraints and mandatory repository rules.
- `CODEX_PLAYBOOK.md` - Codex workflow protocol for safe, minimal, validated edits.
- `System_SPEC.md` - Source-of-truth system specification for behavior and rules.
- `docs/architecture_flows.md` - Flow/connector integration and PAC CLI guidance.
- `docs/collaboration_setup_guide.md` - Step-by-step collaboration guide for Edwin and Recruitment accounts.
- `docs/flows_easy_english.md` - Plain-language explanation of BGV_0 to BGV_6 process flow.
- `docs/progress.md` - Ongoing status log for completed tasks and next actions.
- `flows/main.flow.json` - Placeholder export metadata for main flow.
- `flows/flowrunlogs-exporter.flow.json` - Placeholder export metadata for FlowRunLogs exporter flow.
- `connectors/shared_flowrunops.powerplatform.json` - Placeholder export metadata for shared_flowrunops connector.
- `connectors/new_flowrunops.connector.xml` - Placeholder Dataverse custom connector XML baseline.
- `connectors/new_flowrunops.oauth.parameters.json` - Placeholder OAuth parameter definition for new_flowrunops.
- `scripts/active/import_flow_exports.ps1` - Helper to copy authenticated exported flow JSON files into `flows/` standard filenames.
- `scripts/active/verify_flow_runs.py` - Flow run-history verification script using OAuth and ARM/connector endpoint support.
- `tests/fixtures/connections.mock.json` - Mocked flow/connector connection metadata for tests.
- `tests/test_flow_connector_fixtures.py` - Fixture validation tests for connector/flow mappings.
- `tests/test_verify_flow_runs.py` - Unit tests for flow verification token, run-history fetch, and metadata parsing.
- `Repository Template.docx` - Source template document provided by user.
- `System Specification Template.docx` - Source specification template provided by user.
- `Codex Agent Playbook Template.docx` - Source playbook template provided by user.
