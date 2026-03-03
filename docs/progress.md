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
