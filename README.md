# DL Automation System (BGV)

Power Automate solution repository for `BGV_System` with canonical unpacked flow artifacts, operational scripts, and documentation.

## Purpose
- Keep Power Automate solution artifacts in source control.
- Standardize daily sync/edit/deploy workflow for team members and Codex sessions.
- Enforce linked documentation updates when flow behavior changes.

## Developer + Codex Quick Start
1. Open repo in VS Code at `C:\bgv_project`.
2. Confirm active PAC identity:
   ```powershell
   pac auth who
   ```
3. Run daily sync (recommended first command each day):
   ```powershell
   powershell -File scripts/active/bgv_daily_sync.ps1
   ```
4. If needed, run with tests:
   ```powershell
   powershell -File scripts/active/bgv_daily_sync.ps1 -RunTests
   ```
   If Python is not on PATH:
   ```powershell
   powershell -File scripts/active/bgv_daily_sync.ps1 -RunTests -PythonExe C:\path\to\python.exe
   ```

## Mandatory Flow Edit Rules
- Edit cloud flows only in canonical path:
  - `flows/power-automate/unpacked/Workflows/`
- Treat non-canonical duplicates as read-only unless explicitly requested:
  - `power-automate/`
  - root `BGV_*.json` exports (if present)
- After edits, pack/import back to environment:
  ```powershell
  pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
  pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
  ```

## Run History Utilities
- Single-flow verification:
  ```powershell
  py scripts/active/verify_flow_runs.py
  ```
- All canonical flows (writes combined report):
  ```powershell
  py scripts/active/pull_all_flow_runs.py
  ```
  Output file (default):
  - `out/flow_run_history_latest.json`

## Linked Documentation Policy
When canonical flow JSON files change, linked docs must be updated in the same change.

Required by policy:
- `docs/progress.md`
- At least one behavior doc:
  - `System_SPEC.md`
  - `docs/flows_easy_english.md`
  - `docs/architecture_flows.md`

Enforced by CI:
- `.github/workflows/linked-docs-guard.yml`
- `scripts/active/enforce_linked_docs.py`

## Recommended Prompting Pattern for Codex
When requesting flow fixes, include:
- flow name
- run ID
- expected behavior
- current failure behavior
- whether Codex should deploy to Power Automate after patch

Example:
```text
Patch BGV_5_Response1 filter for RequestID mismatch.
Run ID: <run-id>
Expected: row match and update succeeds.
Current: flow terminates with Failed.
After patch, deploy to BGV_System and verify latest run.
```

## Key Documents
- `AGENTS.md`
- `CODEX_PLAYBOOK.md`
- `System_SPEC.md`
- `docs/collaboration_setup_guide.md`
- `docs/progress.md`
