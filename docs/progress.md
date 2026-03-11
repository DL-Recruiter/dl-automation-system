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

## 2026-03-05 (Shared mailbox routing + BGV_5 Teams destination update)
- Current status:
  - Updated all Outlook send actions across canonical BGV flows to route via shared mailbox `DLRRecruitmentOps@dlresources.com.sg`.
- Completed tasks:
  - Updated flow JSON files:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Converted `SendEmailV2` actions to `SharedMailboxSendEmailV2` where needed and set:
    - `emailMessage/MailboxAddress = DLRRecruitmentOps@dlresources.com.sg`
  - For all email actions inside `BGV_5_Response1`, enforced:
    - `emailMessage/To = DLRRecruitmentOps@dlresources.com.sg`
  - Updated BGV_5 Teams post destination only:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Subject/body/attachments/message HTML were preserved.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - Action inventory script over all canonical flow JSON files to list Outlook/Teams operation IDs and key parameters before/after patch.
  - `Get-Content -Raw <each_changed_flow_json> | ConvertFrom-Json | Out-Null` (implicit via inventory parse).
  - `git diff -- flows/power-automate/unpacked/Workflows/*.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: run one test candidate submission + one BGV_5 notification path to verify emails appear in `DLRRecruitmentOps@dlresources.com.sg` and Teams posts appear in the new destination.

## 2026-03-06 (BGV_4 ID prefill remap: NRIC field with passport fallback)
- Current status:
  - Updated employer prefill mapping so the HR form NRIC field receives candidate identification using NRIC-first, then Passport fallback.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - In `FinalVerificationLink`:
    - kept `r27b6bdb850dd48339dc05df11d485470` and changed fallback chain to:
      - `F1_IDNumberNRIC` -> `F1_IDNumberPassport` -> `IdentificationNumberNRIC` -> `IdentificationNumberPassport`.
    - removed direct prefill mapping for `r0c342001cdd8463181c36dba2a8933ad` (passport field).
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "r27b6bdb850dd48339dc05df11d485470|r0c342001cdd8463181c36dba2a8933ad" flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run one employer-form email send from BGV_4 and confirm candidate passport-only submissions appear in the HR form NRIC field.

## 2026-03-06 (BGV_0 email shard-error fix with shared-mailbox send-as)
- Current status:
  - Patched `BGV_0_CandidateDeclaration` email action to avoid `Group Shard is used in non-Groups URI` runtime failure.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Changed `Send_an_email_(V2)` in `BGV_0`:
    - `operationId`: `SharedMailboxSendEmailV2` -> `SendEmailV2`
    - `emailMessage/MailboxAddress` -> `emailMessage/From` set to `DLRRecruitmentOps@dlresources.com.sg`
  - Preserved subject/body/to/importance unchanged.
  - Updated linked behavior documentation:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "Send_an_email_\(V2\)|SendEmailV2|SharedMailboxSendEmailV2|emailMessage/From|emailMessage/MailboxAddress" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: run one new `BGV_0` submission and confirm candidate receives from shared mailbox identity and flow no longer fails at send step.

## 2026-03-06 (Revert BGV_0 to shared mailbox email action)
- Current status:
  - Updated `BGV_0` email action to use `Send an email from a shared mailbox (V2)` per runtime permission model.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - In `Send_an_email_(V2)`:
    - `operationId`: `SendEmailV2` -> `SharedMailboxSendEmailV2`
    - `emailMessage/From` -> `emailMessage/MailboxAddress` = `DLRRecruitmentOps@dlresources.com.sg`
  - Preserved `To`, `Subject`, `Body`, links, and formatting unchanged.
  - Confirmed all other BGV email actions already use shared mailbox operation.
  - Updated linked behavior documentation:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json | ConvertFrom-Json | Out-Null`
  - `rg -n "SendEmailV2|SharedMailboxSendEmailV2|emailMessage/MailboxAddress|emailMessage/From" flows/power-automate/unpacked/Workflows`
- Next actions and blockers:
  - Next action: if authorization error persists, grant mailbox-level `Send As` or `Send on behalf` for the Office 365 connection identity against `DLRRecruitmentOps@dlresources.com.sg`.

## 2026-03-06 (Synced manual cloud edit for BGV_0)
- Current status:
  - Exported and unpacked latest cloud solution after manual edit in `BGV_0_CandidateDeclaration`.
- Completed tasks:
  - Updated canonical flow from cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Synced changes observed in flow JSON:
    - Office 365 connection reference renamed to `shared_office365-1` with logical reference `cr94d_sharedoffice365_bdd97`.
    - Email action now named `Send_an_email_from_a_shared_mailbox_(V2)` and uses `SharedMailboxSendEmailV2`.
    - Candidate email subject/body content reflects current manual cloud version.
    - Candidate status update now runs after `Send_an_email_from_a_shared_mailbox_(V2)`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export --name BGV_System --path artifacts/exports/BGV_System_unmanaged.zip --managed false --overwrite`
  - `pac solution unpack --zipfile artifacts/exports/BGV_System_unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: monitor one live BGV_0 run to verify mailbox permissions and successful send from shared mailbox action.

## 2026-03-06 (Mailbox migration: DLRRecruitmentOps -> recruitmentops)
- Current status:
  - Updated all canonical BGV flow email actions to use shared mailbox `recruitmentops@dlresources.com.sg`.
- Completed tasks:
  - Replaced sender mailbox address in workflow JSON files:
    - `BGV_0_CandidateDeclaration`
    - `BGV_3_AuthReminder_5Days`
    - `BGV_4_SendToEmployer_Clean`
    - `BGV_5_Response1`
    - `BGV_6_HRReminderAndEscalation`
  - Updated BGV_5 mailbox-routed recipient constants from old mailbox to new mailbox where applicable.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `rg -n "DLRRecruitmentOps@dlresources.com.sg|recruitmentops@dlresources.com.sg" flows/power-automate/unpacked/Workflows docs/flows_easy_english.md`
  - `ConvertFrom-Json` parse check for all workflow JSON files under canonical path.
- Next actions and blockers:
  - Next action: verify Office 365 connector permission on `recruitmentops@dlresources.com.sg` for the active connection identity.

## 2026-03-06 (BGV_1 signature detection remap to CandidateAuthorisation tag)
- Current status:
  - Fixed signature detection logic to use Word checkbox content-control tag `CandidateAuthorisation` after template control recreation.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Replaced old condition source `Parse_JSON.signedYes` with tag-driven logic:
    - Added `Filter_array_-_CandidateAuthorisation` over `Parse_JSON.controlsFound`
    - Filter criterion: `toLower(item().tag) == 'candidateauthorisation'`
    - Signature condition now requires:
      - filtered array length > 0
      - first match `isChecked == true`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "Filter_array_-_CandidateAuthorisation|candidateauthorisation|isChecked|signedYes" <BGV_1_json>`
- Next actions and blockers:
  - Next action: submit one signed and one unsigned authorization form to confirm `AuthorisationSigned` toggles correctly.

## 2026-03-06 (BGV_1 tag correction: SignedYes)
- Current status:
  - Corrected BGV_1 checkbox detection tag/title to `SignedYes` based on latest template properties.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - Renamed filter action to `Filter_array_-_SignedYes` and changed condition dependencies accordingly.
  - Filter now matches either tag or title (case-insensitive): `SignedYes`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "Filter_array_-_SignedYes|signedyes|CandidateAuthorisation" <BGV_1_json> docs/flows_easy_english.md`
- Next actions and blockers:
  - Next action: test one ticked and one unticked authorization form; ensure only ticked sets `AuthorisationSigned=true`.

## 2026-03-06 (BGV_1 signature detection hardening: signedYes OR SignedYes control)
- Current status:
  - Hardened `BGV_1` signature detection to support both parser summary flag and control-tag path.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
  - `Signature_checkbox_condition` now passes when either:
    - `Parse_JSON.signedYes == true`, or
    - `Filter_array_-_SignedYes` finds a control and first match `isChecked == true`.
  - This avoids false negatives when `controlsFound` is empty but parser still reports signed status.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw <BGV_1_json> | ConvertFrom-Json | Out-Null`
  - `rg -n "signedYes|Filter_array_-_SignedYes|Signature_checkbox_condition|isChecked" <BGV_1_json>`
- Next actions and blockers:
  - Next action: rerun with your signed document and confirm `AuthorisationSigned` flips to true, then test one unsigned sample to ensure no false positive.

## 2026-03-06 (BGV_1/BGV_4 hardening for signed authorization detection)
- Current status:
  - Added tolerant signed-detection logic to reduce false negatives from parser schema and value-type differences.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
      - Signature condition now checks raw `HTTP.signedYes` as true-like string/boolean.
      - Control filter now reads from `HTTP.controlsFound` directly (no dependency on `Parse_JSON` success).
      - Added secondary filter `Filter_array_-_SignedYes_Checked` to require checked state true-like.
      - Tag/title match supports `SignedYes` and compatibility fallback `CandidateAuthorisation`.
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
      - `Condition_-_AuthorisationSigned` now accepts both boolean true and string `"true"`.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks for updated flow JSON files.
  - `rg` checks for updated expressions/actions (`Filter_array_-_SignedYes_Checked`, `toLower(string(body('HTTP')?['signedYes']))`, tolerant `AuthorisationSigned` condition).
- Next actions and blockers:
  - Next action: rerun one known signed file and verify `BGV_1` updates candidate row, then trigger `BGV_4` recurrence to confirm employer send resumes.

## 2026-03-08 (Synced BGV_6 manual Team/Channel update from cloud)
- Current status:
  - Exported and unpacked latest cloud solution after manual BGV_6 escalation destination update in Power Automate.
- Completed tasks:
  - Updated canonical flow from cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed Teams escalation destination in BGV_6 now points to:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export --name BGV_System --path artifacts/exports/BGV_System_unmanaged.zip --managed false --overwrite`
  - `pac solution unpack --zipfile artifacts/exports/BGV_System_unmanaged.zip --folder flows/power-automate/unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - `rg -n "body/recipient/groupId|body/recipient/channelId" flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
- Next actions and blockers:
  - Next action: run a BGV_6 cycle with an escalated item and confirm the Teams message lands in the new channel.

## 2026-03-08 (BGV_0 candidate authorization email wording update)
- Current status:
  - Updated candidate authorization email body text in `BGV_0` to new approved wording.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - In action `Send_an_email_from_a_shared_mailbox_(V2)`:
    - Added greeting: `Dear <dynamic candidate name>,`
    - Kept candidate name expression from existing form response field.
    - Kept existing dynamic authorization link expression unchanged.
    - Updated only surrounding static wording per requested template.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` on updated BGV_0 JSON.
  - `rg` checks for updated email body fragments and dynamic expressions.
- Next actions and blockers:
  - Next action: run one BGV_0 test submission and verify rendered email body in received message.

## 2026-03-09 (BGV_4 employer email subject/body wording refresh)
- Current status:
  - Updated BGV_4 employer email template wording while preserving existing dynamic mappings in declared-details and link sections.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Subject now uses the dynamic mapped company field.
  - Opening section wording now references dynamic company and candidate values while keeping downstream declared company details + verification link block unchanged.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `Get-Content -Raw flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json | ConvertFrom-Json | Out-Null`
  - `git diff -- flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: trigger one BGV_4 run and verify received employer email renders expected company/candidate dynamic values and unchanged declared-details/link section.

## 2026-03-09 (BGV_0 validation error fix: malformed SendAfterDate expression)
- Current status:
  - Fixed a flow-designer validation error in `BGV_0_CandidateDeclaration` caused by a malformed EMP1 `SendAfterDate` expression.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
  - Replaced malformed EMP1 `item/SendAfterDate` expression with valid `@utcNow()` to match EMP2/EMP3 behavior.
  - Ran full JSON syntax validation on all canonical workflows (`BGV_0` to `BGV_6`).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` validation for all files under `flows/power-automate/unpacked/Workflows/*.json`
  - `rg -n "item/SendAfterDate" flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- Next actions and blockers:
  - Next action: import updated solution and run one live BGV_0 submission to confirm designer validation passes and run succeeds.

## 2026-03-09 (BGV_4 employer email wording sync)
- Current status:
  - Updated BGV_4 employer email template wording in canonical flow after cloud still showed old text.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Preserved existing dynamic mappings in subject, declared company details block, and verification link block.
  - Updated opening body sentence to use dynamic candidate full name and dynamic company name wording.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_4 JSON
  - `rg -n "emailMessage/Subject|emailMessage/Body|Declared company details from candidate|FinalVerificationLink"` on BGV_4 JSON
- Next actions and blockers:
  - Next action: run one BGV_4 send cycle and confirm new intro wording appears in sent email.

## 2026-03-09 (BGV_6 escalation Teams destination remap)
- Current status:
  - Remapped BGV_6 escalation post destination from old main-channel IDs to the DLR Recruitment Ops BGV channel IDs.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_6:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_6 JSON
  - `rg -n "groupId|channelId"` on BGV_6 JSON
- Next actions and blockers:
  - Next action: run one BGV_6 escalation cycle and verify message lands in `DLR Recruitment Ops > BGV` channel.

## 2026-03-09 (BGV_3 escalation Teams destination remap)
- Current status:
  - Remapped BGV_3 day-5 escalation Teams post to the DLR Recruitment Ops BGV channel for consistency with BGV_6/BGV_5.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_3:
    - `body/recipient/groupId = b680487c-a11c-44f4-9de6-8813d3e2951b`
    - `body/recipient/channelId = 19:NcAD8P3aERodeV2-NR6D9OBEOnwZI62MVLgNoBrSIl01@thread.tacv2`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_3 JSON
  - `rg -n "groupId|channelId"` on BGV_3 JSON
- Next actions and blockers:
  - Next action: trigger a day-5 escalation scenario and verify Teams post lands in `DLR Recruitment Ops > BGV`.

## 2026-03-09 (BGV_4 sends signed form copy to candidate)
- Current status:
  - Added candidate-copy email behavior so the same signed authorization form sent to employer is also sent to the candidate.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Added action `Send_signed_form_copy_to_candidate_(V2)` after employer send.
  - Reused the same attachment payload (`AuthFileName` + `Get_file_content`) and shared mailbox sender.
  - Candidate recipient mapping uses `Get_item.body/CandidateEmail` with fallback to `recruitmentops@dlresources.com.sg` if invalid.
  - Updated request status update runAfter to execute after candidate-copy email succeeds.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_4 JSON
  - `rg -n "Send_signed_form_copy_to_candidate_\(V2\)|emailMessage/To|CandidateEmail"` on BGV_4 JSON
- Next actions and blockers:
  - Next action: trigger one BGV_4 run and verify both employer and candidate receive the same signed form attachment.

## 2026-03-10 (BGV_6 remap correction using live Graph IDs)
- Current status:
  - Corrected BGV_6 Teams escalation destination after verifying actual Team/Channel IDs from Microsoft Graph.
- Completed tasks:
  - Verified live Teams IDs via Graph:
    - `DLR Recruitment Ops` team: `4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `BGV` channel: `19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Updated linked behavior docs:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_6 JSON
  - `rg -n "groupId|channelId"` on BGV_6 JSON
- Next actions and blockers:
  - Next action: trigger BGV_6 escalation and verify post appears in `DLR Recruitment Ops > BGV`.

## 2026-03-10 (BGV_3 and BGV_6 reminder condition repair after cloud sync)
- Current status:
  - Synced latest cloud solution first (export/unpack), then repaired reminder condition mappings in BGV_3 and BGV_6.
- Completed tasks:
  - Performed PAC-first sync from cloud:
    - `pac solution export --name BGV_System ...`
    - `pac solution unpack ...`
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 fixes:
    - corrected day-5 escalation expression to `@outputs('DaysSinceLink')`
    - aligned reminder field checks to `LastAuthReminderAt` (removed stale `LastAuthReminderSentAt` usage)
    - removed incorrect `item/ConsentCaptured = true` update from reminder stamp action
  - BGV_6 fixes:
    - replaced unstable dependencies on `outputs('Update_item')` / `outputs('Update_item_1')` with current-loop values `items('Apply_to_each')` in reminder conditions and notification bodies
    - updated final reminder item patch target ID to `@items('Apply_to_each')?['ID']`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks for updated BGV_3 and BGV_6 JSON files
  - `rg` checks to confirm broken references were removed
- Next actions and blockers:
  - Next action: run one controlled reminder test for each flow (BGV_3 daily reminder and BGV_6 reminder/escalation timeline) and confirm expected branch execution in run history.

## 2026-03-10 (BGV_3 non-sending reminder root-cause fix)
- Current status:
  - Identified why BGV_3 reminders were still not sending for some pending candidates.
- Root cause:
  - Outer BGV_3 gate used `ConsentCaptured`; legacy rows with this flag set could bypass reminder branch even while status remained pending.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
  - Changed outer gate condition to use `AuthorisationSigned == true` check (true -> skip, false/null -> continue reminder logic).
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated BGV_3 JSON
  - `rg -n "AuthorisationSigned|ConsentCaptured"` on BGV_3 JSON
- Next actions and blockers:
  - Next action: run BGV_3 once with a pending candidate and confirm `Send_an_email_(V2)` executes.

## 2026-03-10 (BGV_5 Teams channel aligned to DLR Recruitment Ops > BGV)
- Current status:
  - Aligned BGV_5 Teams post destination to the same `DLR Recruitment Ops > BGV` channel used by BGV_6.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Updated Teams destination values in BGV_5:
    - `body/recipient/groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `body/recipient/channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Re-validated BGV_6 mapping remains correct to the same IDs.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on BGV_5 and BGV_6 JSON
  - `rg -n "body/recipient/groupId|body/recipient/channelId"` on BGV_5 and BGV_6
- Next actions and blockers:
  - Next action: trigger one BGV_5 high-severity response and one BGV_6 escalation to confirm both posts appear in `DLR Recruitment Ops > BGV`.

## 2026-03-10 (BGV_5 recruiter email bodies include EmployerName)
- Current status:
  - Updated recruiter-facing BGV_5 email bodies to include `EmployerName` while preserving all existing logic/content.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Added `EmployerName` line into both recruiter email bodies:
    - `Send_an_email_-_High_Severity_(V2)`
    - `Send_an_email_(V2)_1`
  - Revalidated BGV_6 JSON and destination mapping remained stable.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on BGV_5 and BGV_6 JSON
  - `rg` checks on updated BGV_5 email body fields and mapping references
- Next actions and blockers:
  - Next action: run one normal and one high-severity BGV_5 submission to verify both recruiter emails render EmployerName correctly.

## 2026-03-10 (Temporary 5-minute test mode for BGV_3 and BGV_6 reminders)
- Current status:
  - Enabled temporary high-frequency test mode so reminder behavior can be validated within ~2 hours.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Recurrence changes:
    - BGV_3: `Day/1` -> `Minute/5`
    - BGV_6: `Day/1` -> `Minute/5`
  - BGV_3 test timeline:
    - `DaysSinceLink` switched from day-units to minute-units (ticks divisor `600000000`)
    - Reminder send window: `5` to `120` minutes since link created
    - Repeat-reminder guard: allow resend when `LastAuthReminderAt <= utcNow()-10 minutes`
    - Escalation window: `30` to `120` minutes since link created
  - BGV_6 test timeline:
    - Reminder 1: `HRRequestSentAt <= utcNow()-10 minutes`
    - Reminder 2: `Reminder1At <= utcNow()-20 minutes`
    - Escalation: `Reminder2At <= utcNow()-20 minutes`
    - Final reminder: `HRRequestSentAt <= utcNow()-90 minutes`
  - Rollback values (post-test):
    - BGV_3 recurrence back to `Day/1`; day-based thresholds back to `1..5` day window and day-5 escalation
    - BGV_6 recurrence back to `Day/1`; thresholds back to `2d / 3d / 1d / 11d`
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `rg` checks for recurrence and `addMinutes(...)` threshold updates
- Next actions and blockers:
  - Next action: run live 2-hour test cycle and then revert to production timeline once validated.

## 2026-03-10 (Daily sync review and operator-doc alignment)
- Current status:
  - Ran the daily sync successfully after adding the explicit Power Platform environment URL override.
  - Reviewed the newly synced canonical flow diffs and confirmed they were formatting-only export changes, not behavior changes.
- Completed tasks:
  - Ran:
    - `powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - Verified the synced flow changes under `flows/power-automate/unpacked/Workflows/` only removed trailing final newlines (`No newline at end of file` diff markers).
  - Updated operator docs so daily sync instructions match the command that actually succeeded in this environment:
    - `README.md`
    - `docs/collaboration_setup_guide.md`
    - `docs/ms365_authentication_runbook.md`
  - Added guidance covering:
    - how to recover when `pac solution export` fails with `No active environment set`
    - recommended use of `-EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
    - when a sync diff is formatting-only and does not require behavior-doc updates
  - Intentionally left behavior docs unchanged because no flow logic changed:
    - `docs/flows_easy_english.md`
    - `docs/architecture_flows.md`
    - `System_SPEC.md`
- Validation commands run:
  - `git diff --stat`
  - `git diff -- flows/power-automate/unpacked/Workflows/`
  - `powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`
  - `git status --short --branch`
- Next actions and blockers:
  - Next action: if desired, update `scripts/active/bgv_daily_sync.ps1` to default from `POWER_PLATFORM_ENV_URL` so operators do not need to pass `-EnvironmentUrl` manually.

## 2026-03-10 (README repo-verification safeguard)
- Current status:
  - Added explicit instructions to help operators and Codex confirm they are working in the correct BGV Git repo before running any Git or PAC command.
- Completed tasks:
  - Updated `README.md`.
  - Added a dedicated repo-verification section with the expected local path, GitHub remote, and normal branch name for this project.
  - Added repo-verification steps to the top-level rules, start-of-day flow, and GitHub workflow checklist.
  - Mirrored the same safeguard into:
    - `docs/collaboration_setup_guide.md`
    - `docs/ms365_authentication_runbook.md`
  - Corrected the outdated local path reference `C:\bgv_project` to the actual repo path `C:\DLR Automation VS Studio Code\bgv_project` in the collaboration guide.
- Validation commands run:
  - `git diff -- README.md docs/collaboration_setup_guide.md docs/ms365_authentication_runbook.md docs/progress.md`
- Next actions and blockers:
  - No blocker. Next action: commit only the docs updates when ready.

## 2026-03-10 (Cloud sync: BGV_4 employer email update)
- Current status:
  - Synced latest cloud flow definitions after manual BGV_4 employer email edits in Power Automate.
- Completed tasks:
  - Exported and unpacked latest unmanaged solution from cloud into canonical path.
  - Confirmed updated BGV_4 employer send action subject/body text is now reflected in canonical JSON.
  - Synced resulting canonical workflow files updated by the cloud export:
    - `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json.data.xml`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Other/Customizations.xml`
    - `flows/power-automate/unpacked/Other/Solution.xml`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export ...`
  - `pac solution unpack ...`
  - `git diff` review for canonical flow artifacts.
- Next actions and blockers:
  - Next action: commit and push synced canonical artifacts.

## 2026-03-10 (Cloud sync: BGV_4 employer email update refresh)
- Current status:
  - Synced another manual BGV_4 employer email edit from cloud to canonical repo artifacts.
- Completed tasks:
  - Exported and unpacked the latest unmanaged `BGV_System` solution.
  - Confirmed only canonical BGV_4 workflow JSON changed in this refresh:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed BGV_4 employer email body now includes the newest cloud-edited HR instruction text while preserving existing dynamic mappings.
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `pac auth who`
  - `pac solution export ...`
  - `pac solution unpack ...`
  - `git status --short`
  - `git diff -- ...BGV_4...json`
- Next actions and blockers:
  - Next action: commit and push synced canonical artifacts.

## 2026-03-10 (Beginner SharePoint list user guide)
- Current status:
  - Added a new beginner-friendly document so future users can
    understand what the main BGV SharePoint lists are for and what their
    important columns mean.
- Completed tasks:
  - Added:
    - `docs/sharepoint_list_user_guide.md`
  - The new guide explains the automation-facing business columns for:
    - `BGV_Candidates`
    - `BGV_Requests`
    - `BGV_FormData`
    - `BGV Records` document library
  - For each store, documented:
    - what the store is for
    - what the important columns mean
    - which flows mainly write the column
    - which flows mainly read the column
  - Linked the new guide from:
    - `README.md`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
  - Kept the guide focused on automation-facing business columns rather
    than trying to guess every default SharePoint system field.
- Validation commands run:
  - `git diff -- README.md docs/sharepoint_list_user_guide.md docs/file_index.md docs/repo_inventory.md docs/progress.md`
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - Existing markdownlint issues remain in older files such as
    `README.md`, `docs/file_index.md`, and `docs/repo_inventory.md`, but
    those are pre-existing and were not expanded as part of this task.
  - If needed later, add a separate live-schema document for full
    SharePoint column dumps including default system metadata.

## 2026-03-10 (`Severity/Value` explanation added to user guide)
- Current status:
  - Expanded the beginner SharePoint guide to explain how
    `Severity/Value` is calculated in the employer-response flow.
- Completed tasks:
  - Updated `docs/sharepoint_list_user_guide.md`.
  - Added a dedicated explanation section for `BGV_Requests.Severity`
    covering:
    - default starting state
    - High / Medium / Low priority order
    - why the contact-request answer does not change severity by itself
    - where the matching notes/result are stored
  - Clarified that `BGV_FormData.F2_Severity/Value` is the copied final
    severity from the same scoring logic.
- Validation commands run:
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - No blocker.

## 2026-03-10 (BGV_5 severity model updated: remove Low, inaccurate info -> Medium)
- Current status:
  - Updated the canonical employer-response flow so the old `Low`
    severity path is no longer used.
- Completed tasks:
  - Updated canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Changed the inaccurate-information rule from:
    - `Low` only when severity was empty
  - To:
    - `Medium` when severity is not already `High`
  - Updated the inaccurate-information path so it now:
    - sets `varSeverity = Medium` when not already High
    - sets `varOutcome = Needs Clarification`
    - sets `varNotifyTeams = true`
    - appends a `[Medium]` note instead of a `[Low]` note
  - Confirmed notes are still written to:
    - `BGV_Requests.Notes`
    - `BGV_FormData.F2_Notes` when the matching FormData row exists
  - Updated linked docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `ConvertFrom-Json` check on updated `BGV_5_Response1` JSON
  - `rg -n "Low|Medium|F2_Notes|Notes|Please contact me for further clarification"` on updated flow/docs
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - Next action: deploy the updated canonical flow and run one employer
    response test for each case:
    - inaccurate info only -> expect `Medium`
    - MAS or disciplinary trigger -> expect `High`
    - contact-request only -> expect note + notification without
      changing severity by itself

## 2026-03-10 (Document how HR form answers are captured in the user guide)
- Current status:
  - Added a beginner-friendly reference section to explain where common
    HR Form 2 answers are stored today.
- Completed tasks:
  - Updated:
    - `docs/sharepoint_list_user_guide.md`
  - Added a new table covering:
    - structured capture into `F2_*` fields
    - notes-only capture into `BGV_Requests.Notes` and
      `BGV_FormData.F2_Notes`
    - raw-JSON-only capture in `BGV_FormData.Form2RawJson`
  - Explicitly documented the current behavior for:
    - inaccurate-information multi-select answers
    - company-details discrepancy fields
    - MAS and disciplinary free-text fields
    - `Other comments we should know about`
    - `Please contact me for further clarification`
- Validation commands run:
  - `npx markdownlint-cli2 docs/sharepoint_list_user_guide.md`
- Next actions and blockers:
  - No blocker.

## 2026-03-11 (Temporary 4-hour reminder test mode re-enabled for BGV_3 and BGV_6)
- Current status:
  - Re-enabled temporary high-frequency reminder timing so both reminder flows can be validated live within a 4-hour window and rolled back cleanly afterward.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 temporary test settings:
    - recurrence changed to `Minute / 5`
    - `DaysSinceLink` switched from day-based ticks to minute-based ticks (`600000000`)
    - reminder send window changed to minute `5` through minute `240`
    - resend guard changed to `LastAuthReminderAt <= utcNow()-5 minutes`
    - escalation trigger changed to minute `20`
  - BGV_6 temporary test settings:
    - recurrence changed to `Minute / 5`
    - Reminder 1 changed to `HRRequestSentAt <= utcNow()-5 minutes`
    - Reminder 2 changed to `Reminder1At <= utcNow()-5 minutes`
    - recruiter escalation changed to `Reminder2At <= utcNow()-5 minutes`
    - final reminder changed to `HRRequestSentAt <= utcNow()-20 minutes`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
  - Rollback values preserved for later restoration:
    - BGV_3 back to `Day / 1`, day-based ticks, day `1..5` reminder window, day `5` escalation
    - BGV_6 back to `Day / 1`, `2d / 3d / 1d / 11d` thresholds
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `git diff -- flows/...BGV_3... flows/...BGV_6... docs/flows_easy_english.md docs/progress.md`
- Next actions and blockers:
  - Next action: pack/import via PAC, then run live tests against one pending candidate and one pending HR request.

## 2026-03-11 (BGV_3 and BGV_6 reminder flows reverted to production timing and repaired)
- Current status:
  - Reverted the temporary reminder test mode and repaired the production reminder logic defects that were causing skipped reminder emails and inconsistent escalation behavior.
- Completed tasks:
  - Updated canonical flows:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - BGV_3 repairs:
    - reverted recurrence from `Minute / 5` back to `Day / 1`
    - reverted `DaysSinceLink` from minute-based ticks back to day-based ticks (`864000000000`)
    - reverted reminder window from minute `5..240` back to day `1..5`
    - reverted same-day resend guard to the original date-based check
    - moved day-5 escalation out of the reminder-send branch so escalation no longer depends on that day's reminder email being sent
    - changed day-5 escalation email to use current candidate values directly instead of the reminder update action output
    - allowed day-5 escalation email to continue even if the Teams post fails
    - confirmed the reminder update still only stamps `LastAuthReminderAt` and does not set candidate status to `Obtained Authorization Form Signature`
  - BGV_6 repairs:
    - reverted recurrence from `Minute / 5` back to `Day / 1`
    - reverted thresholds back to `2d / 3d / 1d / 11d`
    - replaced brittle `""` date comparisons with `empty(...)` checks for `Reminder1At`, `Reminder2At`, `Reminder3At`, and `ResponseReceivedAt`
  - Updated linked behavior doc:
    - `docs/flows_easy_english.md`
- Validation commands run:
  - `ConvertFrom-Json` checks on updated BGV_3 and BGV_6 JSON
  - `Get-ChildItem flows/power-automate/unpacked/Workflows/*.json | ... ConvertFrom-Json`
  - `git diff -- flows/...BGV_3... flows/...BGV_6...`
- Next actions and blockers:
  - Next action: push/import repaired production reminder flows, then verify one pending candidate and one pending employer request against live run history.

## 2026-03-11 (BGV_4 prefilled employer form mapping restored to cloud from canonical source)
- Current status:
  - Verified the canonical `BGV_4_SendToEmployer_Clean` flow still contained the expected Microsoft Forms prefill mapping, then re-imported the solution so the live Power Automate version matches GitHub again.
- Completed tasks:
  - Inspected canonical flow:
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
  - Confirmed `FinalVerificationLink` still maps the employer verification form prefill fields for:
    - candidate full name
    - identification number
    - request ID
    - employer name
    - employer UEN
    - employer address
    - employment period
    - last drawn salary
    - job title
  - Repacked and re-imported the current canonical solution to restore those mappings to the cloud flow.
- Validation commands run:
  - `rg -n "FinalVerificationLink|r4930|r27b6|rd745|rccaf|rcf35|r19aa|r0bef|ra6ab|r49ca" ...BGV_4...json`
  - `ConvertFrom-Json` on canonical BGV_4 JSON
  - `pac solution pack ...`
  - `pac solution import ... --publish-changes --force-overwrite`
- Next actions and blockers:
  - Next action: trigger one BGV_4 send cycle and confirm the live employer form link arrives with the expected prefilled values.

## 2026-03-11 (HR form Q8/Q9 mapping correction from prefilled URL)
- Current status:
  - Corrected the HR form inventory so the company-details section matches
    the latest user-provided Microsoft Forms prefilled URL.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md`.
  - Corrected the question numbering for the early company-details block:
    - Q7 = company-details accuracy yes/no (`r2d39255c2449439096683ca0e39241b0`)
    - Q8 = company-details discrepancy multi-select (`rd05170e51ac34fef95f5464cf348bedc`)
    - Q9 = company-details discrepancy explanation (`ra03058e9bbfd40d28014b0c669e92434`)
  - Clarified that these keys are currently known from the prefilled URL
    but are not wired in canonical flow JSON.
- Validation commands run:
  - `rg -n "rd05170e51ac34fef95f5464cf348bedc|ra03058e9bbfd40d28014b0c669e92434|Q7|Q8|Q9" docs/data_mapping_dictionary.md`
- Next actions and blockers:
  - Next action: if needed, capture the exact Microsoft Forms designer
    labels for Q7-Q9 from the live form editor or PDF export and replace
    the current inferred wording.

## 2026-03-11 (BGV report summary template added to local repo)
- Current status:
  - Added the existing Word summary template into the local `bgv_project`
    repo so it is available alongside the mapping docs it depends on.
- Completed tasks:
  - Copied `BGV_Report_Summary_Template.docx` from:
    - `C:\Users\EdwinTeo\Desktop\bgv_project\BGV_Report_Summary_Template.docx`
  - Added the copied file to the repo root:
    - `BGV_Report_Summary_Template.docx`
  - Updated repo index docs:
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
  - Kept flow JSON and SharePoint behavior docs unchanged in this task
    because this change only adds the report template artifact and does
    not change runtime automation behavior.
- Validation commands run:
  - `Get-Item BGV_Report_Summary_Template.docx | Select-Object FullName,Length,LastWriteTime`
  - DOCX text extraction check on `word/document.xml` to confirm the
    copied file contains the expected `BGV Report Summary Template`
    heading and the corrected Q8/Q9/Q15 sections.
- Next actions and blockers:
  - Next action: if desired, update `docs/data_mapping_dictionary.md`
    further so its visible Form 2 inventory fully mirrors every field
    already listed in the Word template.

## 2026-03-11 (BGV report summary template rebuilt with key-based placeholders)
- Current status:
  - Rebuilt the local Word summary template into a simpler single-report
    layout for both Microsoft Forms using the verified form IDs already
    available in the repo.
- Completed tasks:
  - Updated `BGV_Report_Summary_Template.docx`.
  - Replaced generic `Form2.Q1`-style placeholders with key-based
    placeholders such as:
    - `{{Form1.rfe96c622120343f294de908deb0e849d}}`
    - `{{Form2.rd05170e51ac34fef95f5464cf348bedc}}`
    - `{{Form2.r72b23e4aa192405091846e1279085029}}`
  - Added both source Microsoft Form IDs near the top of the template.
  - Preserved the requested additive-path wording:
    - new Azure Function-generated `.docx`
    - saved into `BGV Records`
    - no current `BGV_5` Word-template action
    - no live cloud template upload / file ID mapping in this task
  - Kept Form 1 limited to non-repeating fields only.
  - Kept a short manual-review note for unresolved upload-style fields.
- Validation commands run:
  - DOCX text extraction check on `word/document.xml` to confirm:
    - requested additive-path sentence is present
    - both Form IDs are present
    - key-based response placeholders for Form 1 and Form 2 are present
  - `Get-Item BGV_Report_Summary_Template.docx | Select-Object FullName,Length,LastWriteTime`
- Next actions and blockers:
  - Next action: if needed, align the remaining Form 2 question labels in
    `docs/data_mapping_dictionary.md` to the same visible-question layout
    now used by the Word template.

## 2026-03-11 (Local-only save state confirmed)
- Current status:
  - Confirmed the latest documentation and report-template changes are
    saved locally in the working tree and intentionally not committed yet.
- Completed tasks:
  - Confirmed local on-disk state for:
    - `BGV_Report_Summary_Template.docx`
    - `docs/data_mapping_dictionary.md`
    - `docs/file_index.md`
    - `docs/repo_inventory.md`
    - `docs/progress.md`
  - Confirmed the untracked local files currently kept for later commit:
    - `BGV_Report_Summary_Template.docx`
    - `docs/sharepoint_list_user_guide.md`
  - Confirmed no Git commit was created in this task.
- Validation commands run:
  - `git status --short`
- Next actions and blockers:
  - Next action: stage and commit the intended files when ready.

## 2026-03-11 (Separate GitHub sync clone created and local repo integrated)
- Current status:
  - Created a separate local clone of the current GitHub repo and merged
    the relevant remote changes into the active working repo without
    creating a commit.
- Completed tasks:
  - Cloned current GitHub `master` into:
    - `C:\DLR Automation VS Studio Code\bgv_project_github_sync`
  - Compared the sync clone against the active working tree and isolated
    the files that still differed from current GitHub state.
  - Synced these canonical workflow files to the current GitHub version:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
    - `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`
  - Preserved local `BGV_5` severity/note work while integrating the
    current GitHub high-severity email-body wording into:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Merged linked documentation so the working repo now contains:
    - the missing remote cloud-sync entries in `docs/progress.md`
    - updated behavior wording in `docs/flows_easy_english.md`
- Validation commands run:
  - `git fetch origin`
  - `git rev-list --left-right --count HEAD...origin/master`
  - file-hash / text comparisons between the active repo and `bgv_project_github_sync`
  - three-way merge feasibility checks against `HEAD` for docs and workflow files
- Next actions and blockers:
  - Next action: review the newly integrated unstaged workflow/doc changes
    before deciding whether to stage them for a later commit.

## 2026-03-11 (BGV_5 inaccurate-information path reverted to GitHub Low behavior)
- Current status:
  - Reverted the local-only `BGV_5` inaccurate-information path from the
    earlier `Medium + Needs Clarification + notify` behavior back to
    the current GitHub `Low` behavior, while leaving `BGV_4` unchanged.
- Completed tasks:
  - Updated the canonical workflow file:
    - `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
  - Restored the inaccurate-information branch to:
    - set `Severity = Low` only when `varSeverity` is still empty
    - stop setting `Outcome = Needs Clarification` for that branch
    - stop setting `varNotifyTeams = true` for that branch
    - append the GitHub-style `[Low]` note body
  - Aligned the linked behavior docs:
    - `docs/flows_easy_english.md`
    - `docs/data_mapping_dictionary.md`
    - `docs/sharepoint_list_user_guide.md`
- Validation commands run:
  - `ConvertFrom-Json` on the updated canonical `BGV_5` file
  - `rg -n "Low|Medium|Needs Clarification|Notify_Teams_4|Outcome_4|Information inaccurate" ...`
- Next actions and blockers:
  - Next action: decide whether to keep the temporary
    `bgv_project_github_sync` clone after the final Git history
    integration is complete.

## 2026-03-11 (Q11 mapping doc corrected and local branch rebased onto origin/master)
- Current status:
  - Corrected the documented Form 2 `Q11` behavior and integrated the
    7 remote GitHub commits into the active repo by rebasing the local
    work on top of `origin/master`.
- Completed tasks:
  - Updated `docs/data_mapping_dictionary.md` so Form 2 `Q11`
    (`r513ad5ab3a14453286bdb910820985ec`) is described as response-only:
    - not currently prefilled by `BGV_4`
    - entered manually by employer HR in Form 2
    - stored in `BGV_FormData.F2_ReasonForLeaving`
  - Created a local checkpoint commit before rebase:
    - `04926c9 docs: integrate local BGV updates before upstream rebase`
  - Rebased that local commit onto the current `origin/master`.
  - Resolved rebase conflicts by keeping the current GitHub production
    reminder logic for:
    - `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
    - `docs/flows_easy_english.md`
  - Rebuilt `docs/progress.md` so it contains both:
    - the 7 remote-commit log entries already on GitHub
    - the local documentation/template/mapping entries created in this repo
- Validation commands run:
  - `git fetch origin`
  - `git pull --rebase origin master`
  - `git hash-object ...BGV_3...json` compared with `git show origin/master:...BGV_3...json`
- Next actions and blockers:
  - Next action: complete rebase finalization, run final repo validation,
    and review the new local `master` state before any push.

## 2026-03-11 (Form 2 Q11 logic corrected from HR PDF review)
- Current status:
  - Corrected the current Form 2 documentation logic so `Q11` is treated
    as an employer-entered response field, not a `(Declared By Candidate)`
    prefill field.
- Completed tasks:
  - Updated:
    - `docs/data_mapping_dictionary.md`
    - `docs/architecture_flows.md`
  - Clarified the current rule from the HR Form 2 PDF:
    - Form 2 questions explicitly labeled `(Declared By Candidate)` are
      the intended prefill targets in `BGV_4`
    - `Q11` is no longer one of those declared-by-candidate fields
    - `Q11` remains blank in the runtime prefilled URL and is answered
      manually by employer HR
    - the submitted response is still stored in
      `BGV_FormData.F2_ReasonForLeaving`
- Validation commands run:
  - `rg -n "Declared By Candidate|Reason For Leaving|Q11|r513ad5ab3a14453286bdb910820985ec" docs/data_mapping_dictionary.md docs/architecture_flows.md`
- Next actions and blockers:
  - Next action: if the Form 2 layout changes again, re-verify the
    `(Declared By Candidate)` labels before changing `BGV_4` prefill logic.
