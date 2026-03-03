# Repository Inventory

This inventory lists repository-tracked files and what each file is used for.

## Root Files
- `.env.example` - Placeholder environment variables for local setup; contains no secrets.
- `.gitignore` - Git ignore rules for local secrets, caches, outputs, and generated artifacts.
- `README.md` - Repository quick-start for developers/Codex operators, including daily sync/deploy workflow and policy notes.
- `.vscode/settings.json` - VS Code workspace settings.
- `AGENTS.md` - Mandatory operating rules and safety constraints for coding agents.
- `CODEX_PLAYBOOK.md` - Agent workflow/playbook for context loading, edits, validation, and reporting.
- `Codex Agent Playbook Template.docx` - Reference template document.
- `Repository Template.docx` - Reference template document.
- `System Specification Template.docx` - Reference template document.
- `System_SPEC.md` - Source-of-truth system specification for behavior, rules, and contracts.
- `[Content_Types].xml` - Solution package content type manifest.
- `customizations.xml` - Dataverse solution customizations manifest.
- `solution.xml` - Dataverse solution metadata manifest.

## Connector Files
- `connectors/new_flowrunops.connector.xml` - Custom connector definition artifact.
- `connectors/new_flowrunops.oauth.parameters.json` - OAuth parameter definitions for `new_flowrunops` connector.
- `connectors/shared_flowrunops.powerplatform.json` - Shared connector export metadata placeholder.

## Documentation Files
- `docs/architecture_flows.md` - Flow/connector architecture and CLI run-history guidance.
- `docs/collaboration_setup_guide.md` - Collaboration SOP for auth profiles, daily sync, pack/import, and sharing steps.
- `docs/file_index.md` - Quick index of key repository folders and files.
- `docs/flows_easy_english.md` - Plain-language explanation of BGV_0 to BGV_6 business logic.
- `docs/progress.md` - Chronological change log with validation commands, blockers, and next actions.
- `docs/repo_inventory.md` - Full tracked-file inventory with purpose descriptions.

## Flow Export Files
- `flows/main.flow.json` - Placeholder metadata for main flow export.
- `flows/flowrunlogs-exporter.flow.json` - Placeholder metadata for flow-run-logs exporter export.
- `flows/power-automate/exports/BGV_System_1_0_0_2.zip` - Exported unmanaged solution package snapshot.

## Unpacked Solution Metadata Files
- `flows/power-automate/unpacked/Other/Customizations.xml` - Unpacked customizations metadata.
- `flows/power-automate/unpacked/Other/Solution.xml` - Unpacked solution metadata.

## Unpacked Cloud Flow Files
- `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json` - Candidate declaration intake flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_0_CandidateDeclaration`.
- `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json` - Authorization signature detection flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_1_Detect_Authorization_Signature`.
- `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json` - Post-signature cleanup/unsharing flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_2_Postsignature`.
- `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json` - Candidate authorization reminder/escalation flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_3_AuthReminder_5Days`.
- `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json` - Employer request dispatch flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_4_SendToEmployer_Clean`.
- `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json` - Employer response processing/scoring flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_5_Response1`.
- `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json` - HR reminder/escalation follow-up flow definition.
- `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json.data.xml` - Dataverse workflow metadata for `BGV_6_HRReminderAndEscalation`.

## Active Scripts
- `scripts/active/bgv_daily_sync.ps1` - Daily automation helper for auth check, git pull, export, unpack, and optional test run.
- `scripts/active/import_flow_exports.ps1` - Copies exported flow files into repository-standard flow paths.
- `scripts/active/pull_all_flow_runs.py` - Pulls run history for all canonical flow JSON files and writes a combined report.
- `scripts/active/verify_flow_runs.py` - Authenticates and fetches run history for a single configured flow endpoint.

## Test Files
- `tests/fixtures/connections.mock.json` - Mock connection data fixture used by tests.
- `tests/test_flow_connector_fixtures.py` - Validates expected connector/flow fixture relationships.
- `tests/test_pull_all_flow_runs.py` - Tests canonical flow discovery and helper behavior for bulk run-history pull.
- `tests/test_verify_flow_runs.py` - Tests token request, run-history fetch, and URL composition behavior.
