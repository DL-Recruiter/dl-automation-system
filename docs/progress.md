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

## 2026-03-02 (Collaboration setup hardening)
- Current status:
  - Added explicit collaboration rules for dual-account operations and canonical flow edit paths.
- Completed tasks:
  - Verified git and PAC baseline in `C:\bgv_project`.
  - Fast-forwarded local branch to latest `origin/master`.
  - Confirmed environment context and active identity output in PAC CLI.
  - Updated `AGENTS.md` with mandatory canonical flow path:
    - `flows/power-automate/unpacked/Workflows/`
  - Added account/auth discipline section:
    - `edwin.teo@dlresources.com.sg` (dev/admin)
    - `recruitment@dlresources.com.sg` (operations)
  - Added `docs/collaboration_setup_guide.md`:
    - one-time setup
    - daily collaboration loop
    - export/unpack/edit/validate/commit
    - pack/import deployment loop
    - UI-only sharing steps for recruitment account
    - troubleshooting playbook
  - Updated `docs/file_index.md` to include new collaboration guide.
- Validation commands run:
  - `git -C C:\bgv_project pull --ff-only`
  - `pac auth list`
  - `pac env list`
  - `pac auth create --name BGV_EDWIN --environment https://orgde64dc49.crm5.dynamics.com/` (success)
  - `pac auth create --name BGV_RECRUITMENT --environment https://orgde64dc49.crm5.dynamics.com/` (created with wrong user because current sign-in stayed edwin)
  - `pac auth delete --name BGV_RECRUITMENT`
  - `pac auth create --name BGV_EDWIN --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/` (timed out waiting for interactive sign-in)
- Next actions and blockers:
  - Blocker: `pac auth create --deviceCode` needs interactive sign-in completion in browser; this cannot be completed unattended by agent.
  - Next action: run device-code sign-in manually to create a true `BGV_RECRUITMENT` profile with `recruitment@dlresources.com.sg`.

## 2026-03-03 (VS Code automatic flow run pull)
- Current status:
  - Added one-command automation to pull run history for all canonical BGV solution flows from VS Code.
- Completed tasks:
  - Updated `scripts/active/verify_flow_runs.py` with reusable `build_runs_url_for(...)` helper for environment/flow-specific URL composition.
  - Added `scripts/active/pull_all_flow_runs.py` to:
    - discover canonical flow IDs from `flows/power-automate/unpacked/Workflows/`
    - pull run histories for each flow using existing OAuth/token logic
    - write combined JSON report to `out/flow_run_history_latest.json` (configurable via env var)
  - Added `tests/test_pull_all_flow_runs.py` for canonical flow discovery and run query helper coverage.
  - Updated `tests/test_verify_flow_runs.py` for URL composition helper coverage.
  - Updated `.env.example` and docs (`docs/architecture_flows.md`, `docs/file_index.md`) with new command and optional settings.
- Validation commands run:
  - `py -m py_compile scripts/active/verify_flow_runs.py scripts/active/pull_all_flow_runs.py tests/test_verify_flow_runs.py tests/test_pull_all_flow_runs.py` (pass)
  - `py scripts/active/pull_all_flow_runs.py` (expected failure: missing local OAuth env var `FLOW_VERIFY_TENANT_ID`)
  - `py -m pytest tests/test_verify_flow_runs.py tests/test_pull_all_flow_runs.py` (failed: `No module named pytest`)
- Next actions and blockers:
  - Next action: populate local `.env` with `FLOW_VERIFY_TENANT_ID`, `FLOW_VERIFY_CLIENT_ID`, `FLOW_VERIFY_CLIENT_SECRET`, and `FLOW_VERIFY_ENVIRONMENT_ID`, then run `py scripts/active/pull_all_flow_runs.py`.
  - Blocker: OAuth app registration credentials are required for automated run-history retrieval.
  - Blocker: `python` alias is unavailable in current terminal; use `py` launcher or enable Python alias.

## 2026-03-03 (BGV_5 RequestID filter fix)
- Current status:
  - Patched `BGV_5_Response1` flow to remove unintended whitespace in SharePoint RequestID filter expression.
- Completed tasks:
  - Updated canonical flow file:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `$filter` from spaced RequestID comparison to exact match:
    - `RequestID eq '@{outputs('Get_response_details')?['body/rd745d133eb7f4611b59ea051f980f97a']}'`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null` (pass)
  - `Select-String -Path flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json -SimpleMatch '"$filter"'` (confirmed updated line)
- Next actions and blockers:
  - Next action: rerun `BGV_5_Response1` with a new employer form response and confirm `Get_items` returns 1 row and flow no longer terminates in else branch.

## 2026-03-03 (BGV_5 live failure root-cause and hardening)
- Current status:
  - Investigated failed run `08584290828823558058429050158CU23` in `BGV_5_Response1` after deployment.
  - Confirmed filter spacing issue was fixed, but `Get_items` still returned 0.
- Completed tasks:
  - Pulled live run action inputs/outputs via Flow API.
  - Confirmed `BGV_0` created RequestID with trailing newline (`REQ-BGV-...-EMP1\n`) in existing rows.
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - removed trailing newline artifacts from `item/RequestID` expressions for EMP1/EMP2/EMP3.
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - changed `$filter` to `startswith(RequestID, '<form request id>')` to match both existing newline-suffixed rows and normalized future rows.
  - Repacked and imported updated solution to Power Automate (`BGV_System`) with publish + force overwrite.
- Validation commands run:
  - `ConvertFrom-Json` checks for both patched workflow JSON files (pass).
  - `pac solution pack ...` (pass).
  - `pac solution import ... --publish-changes --force-overwrite` (pass).
- Next actions and blockers:
  - Next action: run a new `BGV_5_Response1` test; verify `Get_items` returns >=1 row and flow does not terminate in else branch.

## 2026-03-03 (Repository inventory documentation)
- Current status:
  - Added a full file-by-file inventory document for the GitHub-tracked repository contents.
- Completed tasks:
  - Added `docs/repo_inventory.md` with purpose descriptions for root files, connectors, docs, flow artifacts, scripts, and tests.
  - Updated `docs/file_index.md` to include `docs/repo_inventory.md`.
- Validation commands run:
  - `git ls-tree -r --name-only origin/master` (confirmed baseline tracked file set for inventory generation)
  - `Get-Content -Raw docs/repo_inventory.md`
- Next actions and blockers:
  - Next action: keep `docs/repo_inventory.md` updated whenever tracked files are added/removed significantly.

## 2026-03-03 (Linked-doc CI enforcement)
- Current status:
  - Added automated GitHub validation to enforce linked documentation updates when canonical flow JSON files change.
- Completed tasks:
  - Added `.github/workflows/linked-docs-guard.yml`:
    - runs on pull requests and pushes to `master`
    - computes diff range and enforces policy check
  - Added `scripts/active/enforce_linked_docs.py`:
    - detects canonical flow JSON changes under `flows/power-automate/unpacked/Workflows/`
    - requires `docs/progress.md` updates
    - requires at least one linked behavior doc update:
      - `System_SPEC.md`
      - `docs/flows_easy_english.md`
      - `docs/architecture_flows.md`
  - Added `tests/test_enforce_linked_docs.py` for pass/fail policy scenarios.
  - Updated `docs/file_index.md` with new workflow/script/test entries.
- Validation commands run:
  - `py -m py_compile scripts/active/enforce_linked_docs.py tests/test_enforce_linked_docs.py`
  - `py scripts/active/enforce_linked_docs.py --base HEAD~1 --head HEAD` (policy execution smoke check)
  - `py -m pytest tests/test_enforce_linked_docs.py` (failed: `No module named pytest`)
- Next actions and blockers:
  - Next action: verify the `Linked Docs Guard` workflow run on next PR/push in GitHub Actions.
  - Blocker: local `pytest` module is not installed in current shell.

## 2026-03-03 (README onboarding and operator guide)
- Current status:
  - Added a root `README.md` with concrete instructions for developers guiding Codex sessions.
- Completed tasks:
  - Added `README.md` with:
    - daily sync commands (`scripts/active/bgv_daily_sync.ps1`)
    - canonical flow edit path rules
    - pack/import deployment commands
    - run-history commands (`verify_flow_runs.py`, `pull_all_flow_runs.py`)
    - linked-doc policy and CI guard references
    - recommended Codex prompt pattern
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` to include the new README purpose.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `Get-Content -Raw docs/file_index.md`
  - `Get-Content -Raw docs/repo_inventory.md`
- Next actions and blockers:
  - Next action: keep README examples updated when script names or deployment commands change.

## 2026-03-03 (README expanded with full user task playbooks)
- Current status:
  - Expanded README with a more explicit, screenshot-style operational guide for users/developers guiding Codex.
- Completed tasks:
  - Updated `README.md` with:
    - explicit answer: sync first
    - one-time setup checklist
    - detailed `bgv_daily_sync.ps1` step-by-step behavior
    - what `bgv_daily_sync.ps1` does not do
    - common task playbooks (start work, investigate failure, patch/deploy, share with teammate)
    - explicit deploy commands and run-history utility commands
    - linked-doc CI policy summary
- Validation commands run:
  - `Get-Content -Raw README.md`
- Next actions and blockers:
  - Next action: if needed, add a short FAQ section for common operator errors (wrong PAC account, stale exports, missing Python launcher).

## 2026-03-03 (README push workflow + best practices)
- Current status:
  - Added missing operator guidance for safe GitHub push workflow and day-to-day best practices.
- Completed tasks:
  - Updated `README.md` with:
    - "How To Push To GitHub (Safe Sequence)" section
    - "Best Practices Checklist" section
  - Included explicit commands for pull/status/add/commit/push and CI verification.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `git status --short`
- Next actions and blockers:
  - Next action: if preferred, add a PR-based workflow variant as the default and keep direct-`master` push as an exception path.

## 2026-03-03 (README deployment runbook: GitHub -> Power Automate -> Production)
- Current status:
  - Added detailed deployment instructions covering source control handoff, environment deployment, production promotion, and rollback.
- Completed tasks:
  - Expanded `README.md` with end-to-end sections:
    - Local -> GitHub
    - GitHub -> Power Automate deployment
    - Production promotion checklist
    - Rollback steps
    - UI-only task boundary list
  - Included explicit command sequences and smoke-test requirements.
- Validation commands run:
  - `Get-Content -Raw README.md`
  - `git status --short --branch`
- Next actions and blockers:
  - Next action: if production has a separate environment URL/profile naming standard, add those exact values to README examples.

## 2026-03-02 (Daily sync script added)
- Current status:
  - Added a one-command script to reduce manual command mistakes during daily flow sync.
- Completed tasks:
  - Added `scripts/active/bgv_daily_sync.ps1` with safe defaults:
    - verifies required commands (`git`, `pac`)
    - prints active PAC identity (`pac auth who`)
    - runs `git pull --ff-only`
    - exports `BGV_System` to `artifacts/exports/`
    - unpacks into canonical folder `flows/power-automate/unpacked/`
    - optional `-RunTests` flag (`python -m pytest -q tests`)
  - Updated `docs/collaboration_setup_guide.md` with one-command usage examples.
  - Updated `docs/file_index.md` to index the new script.
- Validation commands run:
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipExport -SkipUnpack` (PASS)
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipPull -SkipExport -SkipUnpack -RunTests` (FAIL: `python` not on PATH in this shell)
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -SkipPull -SkipExport -SkipUnpack -RunTests -PythonExe C:\ceipal_api_test\.venv\Scripts\python.exe` (PASS)
- Next actions and blockers:
  - Next action: teammate can adopt the one-command daily sync in VS Code terminal.
  - Note: if Python is not in PATH, pass `-PythonExe <full_path_to_python.exe>`.

## 2026-03-03 (BGV_4 employer prefill + email context fix)
- Current status:
  - Patched `BGV_4_SendToEmployer_Clean` so the employer-form link pre-fills company fields that were previously left blank.
- Completed tasks:
  - Retrieved live `BGV_5_Response1` run payload via Flow API and confirmed the second form fields existed but were empty:
    - `r413feb4da00a44258984ab4bc0a0d1c1`
    - `r1e9155da913446b2bda4ca5b56e5b502`
    - `rbe5f659a0dca4526878cf1af042a1af4`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `FinalVerificationLink` now uses `@concat(...)` with URL-encoded prefill query params for:
    - `RequestID` (`rd745...`)
    - declared employer name/address/UEN fields (`r413...`, `r1e...`, `rbe...`)
  - Expanded employer email body to include declared company details (name/address/UEN) so HR can verify context directly in the email.
  - Packed and imported updated solution to Power Automate (`BGV_System`) with publish + force overwrite.
  - Updated linked behavior documentation:
    - `docs/architecture_flows.md`
- Validation commands run:
  - `pac auth who` (confirmed active identity before live Flow API inspection)
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - Flow API checks for run/action payloads (`runs`, `actions/Get_response_details`) to confirm field IDs and blank values before patch.
- Next actions and blockers:
  - Next action: run a fresh end-to-end test from `BGV_0` through `BGV_5` and confirm the second-form company fields prefill.
  - Limitation: `BGV_Requests` currently does not expose dedicated `EmployerAddress`/`EmployerUEN` columns in action output; these values may remain blank unless source columns are added and populated upstream.

## 2026-03-03 (BGV_4 prefill key remap for candidate context fields)
- Current status:
  - Remapped `BGV_4` second-form prefill query keys to the latest Microsoft Forms keys shared from `Get Pre-filled URL`.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `FinalVerificationLink` now maps:
    - `r4930fc603c0f4cada09832be79f2a76f` <- `BGV_Candidates.FullName`
    - `r27b6bdb850dd48339dc05df11d485470` <- `BGV_Candidates.IdentificationNumberNRIC`
    - `r0c342001cdd8463181c36dba2a8933ad` <- `BGV_Candidates.IdentificationNumberPassport`
    - `rd745d133eb7f4611b59ea051f980f97a` <- `BGV_Requests.RequestID`
    - `rccaf3632669648baaa335c12d4ea40bf` <- `BGV_Requests.EmployerName`
  - Updated linked behavior documentation:
    - `docs/architecture_flows.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Select-String` checks for new `r...` keys in `FinalVerificationLink`
- Next actions and blockers:
  - Next action: receive remaining first-form -> second-form field mapping from user, then append additional prefill parameters in `BGV_4`.

## 2026-03-03 (PnP interactive app auth documentation alignment)
- Current status:
  - Captured newly completed PnP interactive app registration details in source-controlled documentation.
- Completed tasks:
  - Updated `System_SPEC.md`:
    - added auth-context separation (`pac` vs flow connector runtime vs PnP).
    - documented PnP interactive app baseline:
      - registration method: `Register-PnPEntraIDAppForInteractiveLogin`
      - app display name: `BGV-PnP-Automation`
      - app client id: `3e59bbcc-3e14-4837-b6e0-0a1870286f31`
    - added env contract entries:
      - `PNP_CLIENT_ID`
      - `PNP_TENANT_ID`
  - Updated `.env.example` with placeholder keys:
    - `PNP_CLIENT_ID`
    - `PNP_TENANT_ID`
  - Updated `docs/collaboration_setup_guide.md` with:
    - PnP login command pattern (`Connect-PnPOnline -Interactive -ClientId -Tenant`)
    - session verification command (`Get-PnPConnection`)
  - Updated `docs/architecture_flows.md` with explicit authentication context separation.
- Validation commands run:
  - `az ad app list --all --query "[?contains(displayName, 'PnP') || contains(displayName, 'PNP')].{displayName:displayName,appId:appId}" -o table`
  - `rg -n "Register-PnPEntraIDAppForInteractiveLogin|PnP|ClientId|TenantId" System_SPEC.md .env.example docs/collaboration_setup_guide.md docs/architecture_flows.md docs/progress.md`
- Next actions and blockers:
  - Next action: on each operator machine, set local `.env` values for `PNP_CLIENT_ID` and `PNP_TENANT_ID` before running PnP list admin commands.

## 2026-03-03 (BGV_FormData wiring across flows 0/4/5 + deployment)
- Current status:
  - Connected the new SharePoint list `BGV_FormData` (list id `f5248a99-fdf1-4660-946a-d54e00575a40`) into the active BGV flow path.
- Completed tasks:
  - Updated canonical flow files:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - add `Create_BGV_FormData_Row_E1/E2/E3` after request-row creation.
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - add `Get_items_(BGV_FormData)` by `RequestID`.
      - use FormData values as preferred source for second-form prefill URL.
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - add `Get_items_(BGV_FormData)` by `RequestID`.
      - add conditional `Update_item_-_BGV_FormData` to persist form-2 normalized fields and raw payload.
  - Repacked and imported `BGV_System` unmanaged solution with publish and overwrite.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: run a fresh end-to-end test (`BGV_0` -> `BGV_4` -> `BGV_5`) and verify `BGV_FormData` rows are created/updated for EMP1/EMP2/EMP3 where provided.

## 2026-03-04 (HR verification mapping quick-reference documented)
- Current status:
  - Added a dedicated quick-reference section for the requested cross-system mapping view:
    `BGV_Candidates` <-> `BGV_Requests` <-> `MS Forms (HR Verification Form)` <-> `Flow 4 outputs`.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` with:
    - current end-to-end path summary (`BGV_4` prefill/send + `BGV_5` response update linkage)
    - focused field mapping table for:
      - candidate identity fields to HR form prefill keys
      - request fields to HR form prefill key and downstream usage
      - Flow 4 SharePoint outputs (`HRRequestSentAt`, `VerificationStatus`) and email recipient field
  - Kept existing detailed sections (Form 1 mapping, Form 2 mapping, risk logic) unchanged.
- Validation commands run:
  - `rg -n "Requested View|2\\.1\\.1|2\\.1\\.2|rd745d133eb7f4611b59ea051f980f97a" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: whenever prefill keys or SharePoint target fields change in `BGV_4`/`BGV_5`, update this quick-reference section in the same commit.

## 2026-03-04 (Canonical field-level mapping dictionary added)
- Current status:
  - Added a single source document for exact current-state field mapping across Microsoft Forms, SharePoint lists, document library, and flows `BGV_0` to `BGV_6`.
- Completed tasks:
  - Added `docs/data_mapping_dictionary.md` with:
    - data store IDs and relationship keys (`CandidateID`, `RequestID`, `RecordKey`)
    - Form 1 -> list/library mappings (including per-slot EMP1/EMP2/EMP3 columns)
    - SharePoint -> Form 2 prefill key mappings (`r...` query params)
    - Form 2 -> `BGV_Requests` / `BGV_FormData` mappings and risk-logic field usage
    - non-form status/reminder field updates across flows `BGV_1`, `BGV_2`, `BGV_3`, `BGV_4`, `BGV_6`
  - Updated `docs/file_index.md` and `docs/repo_inventory.md` to include the new canonical mapping doc.
- Validation commands run:
  - `rg -n "BGV Data Mapping and Data Dictionary|Form 1 response key|Form 2 prefill query key|Form 2 response key" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: when additional Form 2 prefill keys are added in `BGV_4`, update `docs/data_mapping_dictionary.md` in the same commit.

## 2026-03-04 (HR form Q1-Q33 inventory and wiring coverage documented)
- Current status:
  - Captured a full inventory-oriented view for the "Previous Employee Verification - HR Use Only" form and aligned each question to current flow wiring state.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` with a dedicated section:
    - `HR Verification Form (Q1-Q33) Inventory and Wiring Status`
  - Added per-question coverage table with:
    - Forms key (when present in canonical flow JSON)
    - wiring status (`Prefill`, `Read`, `Stored`, `Not wired`)
    - SharePoint target/use notes
  - Included explicit list of fields currently persisted directly into `BGV_FormData` for Form 2.
- Validation commands run:
  - `rg -n "## 11\\) HR Verification Form|Q\\#|F2_InformationAccurate|F2_SelectedIssues|F2_EmployerWouldReEmploy|F2_ReEmployReason" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: capture complete Forms key IDs for currently `Not wired` questions (for example Q6/Q7/Q28/Q29/Q30/Q31/Q33) and wire them in `BGV_5` plus SharePoint columns as needed.

## 2026-03-04 (PDF-annotated prefill pairing captured)
- Current status:
  - Processed user-uploaded annotated PDFs and captured explicit color-circled prefill pairings from Candidate Declaration -> HR Use Only form.
- Completed tasks:
  - Converted both PDFs to local page images and reviewed all pages.
  - Updated `docs/data_mapping_dictionary.md` with section:
    - `User-Annotated Prefill Mapping (PDF Markup, 2026-03-04)`
  - Recorded pairing status as `Implemented` vs `Pending` for:
    - identity fields (name/NRIC/passport)
    - company fields (name/UEN/address)
    - employment fields (period/salary/job title)
  - Marked unresolved key-ID dependency for pending fields where candidate/HR `r...` keys are not yet present in canonical flow JSON.
- Validation commands run:
  - `rg -n "User-Annotated Prefill Mapping|Pending prefill wiring|RequestID remains auto-filled" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Blocker: missing exact Forms key IDs for candidate Q7/Q8/Q10/Q11/Q12/Q13 and HR Q6/Q7/Q10/Q12/Q13 in current canonical flow definitions.
  - Next action: obtain latest Microsoft Forms prefill query keys for HR fields and candidate response keys (from `Get response details` output) before wiring in `BGV_0` and `BGV_4`.

## 2026-03-04 (HR prefill URL keys captured from user)
- Current status:
  - Captured additional HR form prefill keys from user-provided `Get prefilled link` URL for "Previous Employee Verification - HR Use Only".
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` section 11 and section 12 with newly confirmed HR keys:
    - `rcf35c7cc008e472f9d0b84bde67cc1ff` (Company UEN)
    - `r19aae6e8163d4aaeb8a3f3f2d5329be2` (Company Address)
    - `r2d39255c2449439096683ca0e39241b0` (Information Accurate - company details section)
    - `r0bef44c0d22d493f95a33484875b951e` (Employment Period)
    - `r513ad5ab3a14453286bdb910820985ec` (Reason For Leaving)
    - `ra6ab2e26d2d84a92b33148fc4694773a` (Last Drawn Renumeration Package)
    - `r49ca8a655f5e4bcba0e8f75d4475ad77` (Last Position Held)
  - Marked these as `key known; not wired` until canonical flow JSON is patched.
- Validation commands run:
  - `rg -n "rcf35c7cc008e472f9d0b84bde67cc1ff|r19aae6e8163d4aaeb8a3f3f2d5329be2|r2d39255c2449439096683ca0e39241b0|r0bef44c0d22d493f95a33484875b951e|r513ad5ab3a14453286bdb910820985ec|ra6ab2e26d2d84a92b33148fc4694773a|r49ca8a655f5e4bcba0e8f75d4475ad77" docs/data_mapping_dictionary.md`
  - `Get-Content -Raw docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Blocker: matching candidate form response keys are still needed before implementing the remaining prefill wiring in `BGV_4`.
  - Next action: receive user's second response with candidate-form keys, then patch canonical flow JSON and update linked docs in same change.

## 2026-03-04 (Verified candidate->HR mapping wired without assumptions)
- Current status:
  - Completed a strict verification pass for candidate-source key IDs using live Microsoft Forms runtime metadata (not value guessing), then wired the confirmed mappings into canonical flows.
- Completed tasks:
  - Extracted candidate form runtime metadata from:
    - `out/forms/candidate_responsepage.html` -> `prefetchFormUrl`
    - `out/forms/candidate_runtime_form.json`
  - Verified exact candidate source keys for E1/E2/E3 normalized fields (company UEN/address/postal code, job title, salary, employment start/end, HR contact/mobile/email).
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
      - `Create_BGV_FormData_Row_E1/E2/E3` now persist additional normalized Form 1 fields:
        - `F1_EmployerUEN`
        - `F1_EmployerAddress`
        - `F1_EmployerPostalCode`
        - `F1_JobTitle`
        - `F1_LastDrawnSalary`
        - `F1_EmploymentStartDate`
        - `F1_EmploymentEndDate`
        - `F1_HRContactName`
        - `F1_HRMobile`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `FinalVerificationLink` now pre-fills additional HR form keys:
        - `rcf35c7cc008e472f9d0b84bde67cc1ff` (Company UEN)
        - `r19aae6e8163d4aaeb8a3f3f2d5329be2` (Company Address)
        - `r0bef44c0d22d493f95a33484875b951e` (Employment Period: `start to end` when both dates exist, else single available date)
        - `ra6ab2e26d2d84a92b33148fc4694773a` (Last Drawn Salary)
        - `r49ca8a655f5e4bcba0e8f75d4475ad77` (Last Position Held)
  - Verified a current source gap:
    - Candidate declaration runtime metadata has no question with `Reason/Leaving` text, so HR key `r513ad5ab3a14453286bdb910820985ec` remains intentionally unmapped.
  - Updated linked behavior docs:
    - `docs/data_mapping_dictionary.md`
    - `docs/architecture_flows.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_EmployerUEN|F1_EmployerAddress|F1_EmployerPostalCode|F1_JobTitle|F1_LastDrawnSalary|F1_EmploymentStartDate|F1_EmploymentEndDate|F1_HRContactName|F1_HRMobile|rcf35c7cc008e472f9d0b84bde67cc1ff|r19aae6e8163d4aaeb8a3f3f2d5329be2|r0bef44c0d22d493f95a33484875b951e|ra6ab2e26d2d84a92b33148fc4694773a|r49ca8a655f5e4bcba0e8f75d4475ad77" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - `Get-Content out/forms/candidate_e1_verified_fields.json`
  - `NO_REASON_OR_LEAVING_FIELD_FOUND` check via runtime metadata query
- Next actions and blockers:
  - Blocker: HR runtime metadata endpoint currently returns `Required user login` from this non-interactive shell, so HR key inventory remains sourced from user-provided prefill URL + existing flow usage.
  - Next action: run an end-to-end live submission (`BGV_0` -> `BGV_4`) and verify emitted employer link values for Q6/Q7/Q10/Q12/Q13 in actual email.

## 2026-03-04 (flows_easy_english refreshed from canonical unpacked flows)
- Current status:
  - Updated plain-English flow narrative to match latest canonical files under `flows/power-automate/unpacked/Workflows/`.
- Completed tasks:
  - Re-read all canonical workflow JSON files (`BGV_0` to `BGV_6`) and extracted current triggers, action chains, conditions, and key filters.
  - Updated `docs/flows_easy_english.md` with current-state behavior including:
    - `BGV_FormData` creation in `BGV_0` for EMP1/EMP2/EMP3.
    - Prefilled HR form URL behavior in `BGV_4` (candidate + employer + employment context fields).
    - Current request matching/scoring/escalation flow in `BGV_5` including `startswith(RequestID, ...)` matching and FormData update path.
    - Reminder timing logic now documented explicitly for `BGV_6` (2-day, +3-day, +1-day escalation, 11-day final reminder).
- Validation commands run:
  - `Get-ChildItem flows/power-automate/unpacked/Workflows -Filter '*.json'`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw docs/flows_easy_english.md`
- Next actions and blockers:
  - Next action: after each new `pac solution export/unpack`, rerun this same doc refresh so operational wording always matches latest cloud logic.

## 2026-03-05 (BGV_0 EMP2/EMP3 row-check condition fix)
- Current status:
  - Root-cause fixed for missing EMP3 records in `BGV_0_CandidateDeclaration`.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Fixed EMP2 duplicate-check condition to use the correct action output:
    - from `length(body('E1_Row_Check')?['value'])`
    - to `length(body('E2_Row_Check')?['value'])`
  - Fixed EMP3 create condition logic:
    - from invalid `equals(length(body('E3_Row_Check')?['value']), true)`
    - to `equals(length(body('E3_Row_Check')?['value']), 0)` (create only when EMP3 row does not already exist).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (explicit per-slot duplicate-check note for EMP1/EMP2/EMP3 creation path).
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "E2_Row_Check_Condition|E3_Row_Check_Condition|E2_Row_Check|E3_Row_Check|equals\\(length\\(body\\('E3_Row_Check'\\)\\?\\['value'\\]\\), 0\\)" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: run `pac solution pack` + `pac solution import` to deploy this canonical fix to cloud flow, then submit a new candidate form with EMP3 data and verify rows appear in both `BGV_Requests` and `BGV_FormData`.

## 2026-03-05 (Full flow health check + reminder path fixes)
- Current status:
  - Completed repository-wide flow integrity review for canonical workflows (`BGV_0` to `BGV_6`) and patched two reminder-path blockers.
- Completed tasks:
  - Validated all canonical workflow JSON files parse successfully.
  - Verified cross-flow wiring:
    - `BGV_0` EMP1/EMP2/EMP3 row-check conditions now all use `equals(length(...), 0)`.
    - `BGV_4` reads `BGV_FormData` by `RequestID` for prefill.
    - `BGV_5` matches `BGV_Requests` by `startswith(RequestID, ...)` and reads/updates `BGV_FormData` by exact `RequestID`.
  - Fixed `BGV_3` status string mismatch in nested condition:
    - removed trailing space from `Pending Authorization Form Signature ` to `Pending Authorization Form Signature`.
  - Fixed `BGV_6` initial SharePoint query filter field:
    - from `Status eq 'Sent'`
    - to `VerificationStatus eq 'Sent'`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (`BGV_6` selection baseline wording).
- Validation commands run:
  - `Get-ChildItem flows/power-automate/unpacked/Workflows -Filter '*.json' | Get-Content -Raw | ConvertFrom-Json`
  - `pac solution pack --zipfile artifacts/exports/BGV_System_validation_20260305.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `rg` checks for EMP row-check expressions and BGV_FormData RequestID filters.
  - `py scripts/active/pull_all_flow_runs.py` (failed due missing `FLOW_VERIFY_TENANT_ID` local env var).
- Next actions and blockers:
  - Blocker: automated run-history verification requires local OAuth env vars (`FLOW_VERIFY_TENANT_ID`, `FLOW_VERIFY_CLIENT_ID`, `FLOW_VERIFY_CLIENT_SECRET`, `FLOW_VERIFY_ENVIRONMENT_ID`).
  - Next action: import latest packed solution and run one live smoke submission covering EMP3 and reminder paths.

## 2026-03-05 (BGV_4 invalid HR email runtime guard)
- Current status:
  - Patched `BGV_4_SendToEmployer_Clean` to prevent runtime failure when `EmployerHR_Email` contains a name instead of an email address.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Changed `Send_an_email_(V2)` `emailMessage/To` expression to guarded fallback order:
    - `BGV_FormData.F1_HREmail` (if contains `@`)
    - else `BGV_Requests.EmployerHR_Email` (if contains `@`)
    - else `dlresplmain@dlresources.com.sg`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` (`BGV_4` recipient resolution note).
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "emailMessage/To|F1_HREmail|EmployerHR_Email|dlresplmain@dlresources.com.sg" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run a new `BGV_4` recurrence and verify failed request now routes successfully (or falls back) instead of throwing `String/email` conversion error.

## 2026-03-05 (BGV_4 company detail mapping fix + BGV_5 FormData title fix)
- Current status:
  - Patched `BGV_4` and `BGV_5` to address employer-detail mismatch and FormData save validation failure.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - Employer email body now resolves company `Name/Address/UEN` from matching `BGV_FormData` (`F1_EmployerName`, `F1_EmployerAddress`, `F1_EmployerUEN`) before falling back to `BGV_Requests` fields.
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
      - Added `item/Title` to `Update_item_-_BGV_FormData` payload to satisfy required SharePoint `PatchItem` validation.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md` for both fixes.
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_EmployerAddress|F1_EmployerUEN|item/Title|Update_item_-_BGV_FormData" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one live EMP1/EMP2/EMP3 case and verify `BGV_4` email body details match each slot and `BGV_5` save/update now succeeds without `item/Title` error.

## 2026-03-05 (ReasonForLeaving mapped into BGV_FormData for Form1 + Form2)
- Current status:
  - Added end-to-end ReasonForLeaving field mapping into canonical flows for both candidate and employer forms, matched by RequestID/employer slot.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Added Form 1 -> `BGV_FormData.F1_ReasonForLeaving` mappings per slot:
    - EMP1: `r73ad46a6f6e34cb5a811f76061af5d59`
    - EMP2: `r3b040646143e4015a21562a7c692b3d0`
    - EMP3: `r3c7e9cef2f37468fbdb8cb058ac11ce6`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added Form 2 -> `BGV_FormData.F2_ReasonForLeaving` mapping:
    - `r513ad5ab3a14453286bdb910820985ec`
  - Ensured null/empty safety by using `coalesce(...,'')` in both flows.
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_0_json> | ConvertFrom-Json | Out-Null`
  - `Get-Content -Raw <BGV_5_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "F1_ReasonForLeaving|F2_ReasonForLeaving|r73ad46a6f6e34cb5a811f76061af5d59|r3b040646143e4015a21562a7c692b3d0|r3c7e9cef2f37468fbdb8cb058ac11ce6|r513ad5ab3a14453286bdb910820985ec" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one full EMP1/EMP2/EMP3 submission and verify each RequestID row gets the correct `F1_ReasonForLeaving`, then verify employer response writes `F2_ReasonForLeaving` to the same RequestID row.
