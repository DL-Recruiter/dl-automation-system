# Repository Inventory

This inventory lists repository-tracked files and what each file is used for.

Generated `.NET` build/test outputs such as `bin/`, `obj/`, and `TestResults/` are not source-of-truth artifacts and are intentionally kept untracked.

## Root Files
- `.env.example` - Placeholder environment variables for local setup; contains no secrets.
- `.gitignore` - Git ignore rules for local secrets, caches, outputs, and generated artifacts.
- `README.md` - Repository quick-start for developers/Codex operators, including daily sync/deploy workflow and policy notes.
- `.vscode/settings.json` - VS Code workspace settings.
- `AGENTS.md` - Mandatory operating rules and safety constraints for coding agents.
- `CODEX_PLAYBOOK.md` - Agent workflow/playbook for context loading, edits, validation, and reporting.
- `Codex Agent Playbook Template.docx` - Reference template document.
- `BGV_Report_Summary_Template.docx` - Working Word template for additive BGV report summaries built from verified Form 1 and Form 2 question mappings.
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
- `docs/data_mapping_dictionary.md` - Exact field-level mapping and data dictionary for current BGV flow/list/form wiring.
- `docs/file_index.md` - Quick index of key repository folders and files.
- `docs/first_time_and_daily_sop_guide.md` - Reading-order guide that tells collaborators which docs to use for first-time setup, daily work, migration, troubleshooting, and deployment.
- `docs/flows_easy_english.md` - Plain-language explanation of BGV_0 to BGV_6 business logic.
- `docs/ms365_authentication_runbook.md` - Authentication setup and daily verification reference for PAC, Azure, PnP PowerShell, CLI for Microsoft 365, and Graph PowerShell.
- `docs/pev_reference_contact_guardrail.md` - Build-ready guardrail design for the approved HR/reference contact SharePoint list, migration approach, and recruiter approval flow pattern before employer sends.
- `docs/progress.md` - Chronological change log with validation commands, blockers, and next actions.
- `docs/repo_inventory.md` - Full tracked-file inventory with purpose descriptions.
- `docs/sharepoint_list_user_guide.md` - Beginner-friendly user guide to the main BGV SharePoint stores and their important business columns.
- `docs/vscode_ms365_toolchain_guide.md` - Shareable collaborator guide for VS Code extensions, Microsoft 365 tooling, and Codex-assisted sign-in SOPs.

## Flow Export Files
- `flows/main.flow.json` - Placeholder metadata for main flow export.
- `flows/flowrunlogs-exporter.flow.json` - Placeholder metadata for flow-run-logs exporter export.
- `flows/power-automate/exports/BGV_System_1_0_0_2.zip` - Exported unmanaged solution package snapshot.

## Deployment Settings Templates
- `flows/power-automate/deployment-settings/test.settings.template.json` - Test-environment template for connection IDs and `BGV_*` token values used to materialize the green solution.
- `flows/power-automate/deployment-settings/prod.settings.template.json` - Production-environment template for connection IDs and `BGV_*` token values used to materialize the green solution.

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

## Function Files
- `functions/bgv-docx-parser/.gitignore` - Project-specific ignore rules for local settings and generated build outputs.
- `functions/bgv-docx-parser/global.json` - Pinned .NET SDK baseline with feature-band roll-forward for local builds.
- `functions/bgv-docx-parser/bgv-docx-parser.sln` - Visual Studio solution for the BGV DOCX parser function app.
- `functions/bgv-docx-parser/bgv-docx-parser.csproj` - .NET 8 isolated Azure Function project referencing OpenXML and Application Insights.
- `functions/bgv-docx-parser/Program.cs` - Isolated worker host bootstrap and Application Insights service registration for checkbox and Level A drawing detection services.
- `functions/bgv-docx-parser/ParseAuthorizationControls.cs` - HTTP-trigger function that parses authorization DOCX checkbox controls and returns signed-status summary plus additive Level A drawing-detection data.
- `functions/bgv-docx-parser/Models/AuthorizationRequestPayload.cs` - POST request model for `fileName` and `docxBase64`.
- `functions/bgv-docx-parser/Models/AuthorizationResponsePayload.cs` - Backward-compatible response model plus additive Level A drawing-detection payload.
- `functions/bgv-docx-parser/Models/AuthorizationEvaluationResult.cs` - Internal result model for resolved SignedYes/SignedNo matches.
- `functions/bgv-docx-parser/Models/CheckboxControl.cs` - Parsed checkbox content-control model exposed in `controlsFound`.
- `functions/bgv-docx-parser/Models/DrawingDetectionResult.cs` - Response model for additive Level A drawing-detection results.
- `functions/bgv-docx-parser/Models/DrawingDetectionFinding.cs` - Structured drawing-detection finding model with kind, package part URI, and detail.
- `functions/bgv-docx-parser/Services/IDocxCheckboxExtractor.cs` - Service contract for extracting checkbox content controls from DOCX bytes.
- `functions/bgv-docx-parser/Services/OpenXmlDocxCheckboxExtractor.cs` - Current OpenXML implementation for extracting checkbox controls across main document, header, footer, glossary, footnotes, and endnotes parts.
- `functions/bgv-docx-parser/Services/IAuthorizationMatchEvaluator.cs` - Service contract for SignedYes/SignedNo evaluation rules.
- `functions/bgv-docx-parser/Services/AuthorizationMatchEvaluator.cs` - Centralized current matching policy including `CandidateAuthorisation` compatibility and substring fallback.
- `functions/bgv-docx-parser/Services/IDrawingDetectionService.cs` - Service contract for additive Level A drawing detection against DOCX package content.
- `functions/bgv-docx-parser/Services/OpenXmlDrawingDetectionService.cs` - OpenXML package inspector that flags ink, canvas/group, and freeform drawing markers anywhere in the DOCX part graph.
- `functions/bgv-docx-parser/Utilities/RequestBodyReader.cs` - Request-body reader with max-size enforcement for the HTTP trigger.
- `functions/bgv-docx-parser/Utilities/Base64Utilities.cs` - Base64 normalization and decoded-size estimation helpers.
- `functions/bgv-docx-parser/Utilities/FunctionJson.cs` - Shared JSON serializer options used by the function endpoint.
- `functions/bgv-docx-parser/host.json` - Host-level logging and Application Insights settings for the function app.
- `functions/bgv-docx-parser/Properties/launchSettings.json` - Local debug launch profile for the function app.

## Active Scripts
- `scripts/active/bgv_daily_sync.ps1` - Daily automation helper for auth check, git pull, export, unpack, and optional test run.
- `scripts/active/bgv_migration_inventory.ps1` - Inventories source and target SharePoint stores, blue-case migration manifest, template candidates, and target sharing posture.
- `scripts/active/bgv_ensure_target_schema.ps1` - Idempotently creates or verifies the target BGV lists/library, template folder, and uploaded authorization template metadata.
- `scripts/active/bgv_copy_site_data.ps1` - Copies selected candidate/request/form-data rows and related BGV Records files from blue to green with lookup remapping.
- `scripts/active/bgv_build_deployment_settings.ps1` - Creates PAC connection settings, token values, and optional materialized green solution folders from templates plus target schema metadata.
- `scripts/active/bgv_validate_target_migration.ps1` - Validates migrated row/file counts, compares random samples, and reruns the portability guard.
- `scripts/active/pev_import_approved_hr_reference_contacts.py` - Reads the approved HR/reference workbook and prepares or upserts the normalized rows into the live `Approved HR Reference Contacts` SharePoint list.
- `scripts/active/check_bgv_portability.py` - Enforces that canonical flow JSON contains portability tokens instead of old blue-site literals.
- `scripts/active/import_flow_exports.ps1` - Copies exported flow files into repository-standard flow paths.
- `scripts/active/pull_all_flow_runs.py` - Pulls run history for all canonical flow JSON files and writes a combined report.
- `scripts/active/verify_flow_runs.py` - Authenticates and fetches run history for a single configured flow endpoint.

## Shared Modules
- `shared/bgv_migration_common.ps1` - Shared helper module for migration logging, repo-root discovery, SharePoint inventory/manifests, field cloning, JSON output, and Graph template metadata capture.

## Test Files
- `tests/fixtures/connections.mock.json` - Mock connection data fixture used by tests.
- `tests/bgv-docx-parser.tests/bgv-docx-parser.tests.csproj` - .NET unit test project for the parser function services and helpers.
- `tests/bgv-docx-parser.tests/AuthorizationMatchEvaluatorTests.cs` - Unit tests for current SignedYes/SignedNo matching behavior and compatibility alias handling.
- `tests/bgv-docx-parser.tests/Base64UtilitiesTests.cs` - Unit tests for base64 request helper behavior used by the function endpoint.
- `tests/bgv-docx-parser.tests/DocxTestFactory.cs` - Shared deterministic DOCX generator for parser integration test cases.
- `tests/bgv-docx-parser.tests/DrawingDetectionServiceTests.cs` - Deterministic tests for additive Level A drawing detection on empty, grouped/canvas, and ink-marked DOCX packages.
- `tests/bgv-docx-parser.tests/ParserIntegrationTests.cs` - Integration tests that exercise the real OpenXML extractor plus current authorization match evaluation semantics.
- `tests/test_flow_connector_fixtures.py` - Validates expected connector/flow fixture relationships.
- `tests/test_pull_all_flow_runs.py` - Tests canonical flow discovery and helper behavior for bulk run-history pull.
- `tests/test_verify_flow_runs.py` - Tests token request, run-history fetch, and URL composition behavior.
- `tests/test_check_bgv_portability.py` - Tests the BGV portability guard for banned literals and required tokens.

Generated test-project outputs:
- `tests/bgv-docx-parser.tests/bin/` - Local `dotnet build` / `dotnet test` output; intentionally untracked.
- `tests/bgv-docx-parser.tests/obj/` - Local intermediate MSBuild/NuGet output; intentionally untracked.
