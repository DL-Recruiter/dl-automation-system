# DL Automation System (BGV)

Power Automate solution repository for `BGV_System` with canonical unpacked flow artifacts, operational scripts, and documentation.

## Purpose
- Keep Power Automate solution artifacts in source control.
- Standardize daily sync/edit/deploy workflow for team members and Codex sessions.
- Enforce linked documentation updates when flow behavior changes.

## Short Answer: Do I Need To Sync First?
Yes. Always sync first.

Use this command at start of day before editing/testing:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1
```

## One-Time Setup
1. Open repo in VS Code at `C:\bgv_project`.
2. Ensure required tools exist in terminal:
   - `git`
   - `pac`
3. (Optional but recommended) Ensure Python launcher exists for scripts/tests:
   - `py`
4. Confirm PAC identity:
   ```powershell
   pac auth who
   ```

## What `bgv_daily_sync.ps1` Actually Does
`scripts/active/bgv_daily_sync.ps1` is the start-of-day refresh script.

Step by step:
1. Checks prerequisites:
   - validates `git` and `pac` are available
   - confirms current folder is a git repo
2. Shows active Power Platform login:
   - runs `pac auth who`
3. Pulls latest Git changes:
   - runs `git pull --ff-only`
4. Exports latest tenant solution:
   - exports `BGV_System` to `artifacts/exports/BGV_System_unmanaged.zip`
5. Unpacks solution into editable source-controlled files:
   - `flows/power-automate/unpacked/`
6. Optionally runs tests:
   - only when `-RunTests` is passed

What it does NOT do:
- does not auto `git add/commit/push`
- does not auto deploy/import solution back to environment

Typical commands:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1
```

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

## How To Deploy Flow Changes Back To Power Automate
After edits are done:
```powershell
pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
```

## Run History Utilities (VS Code Terminal)
Single-flow verification:
```powershell
py scripts/active/verify_flow_runs.py
```

All canonical flows (combined report):
```powershell
py scripts/active/pull_all_flow_runs.py
```

Default output file:
- `out/flow_run_history_latest.json`

## Common Task Playbooks
### 1) Start Work Safely
1. Run daily sync script.
2. Confirm active account with `pac auth who`.
3. Confirm working tree before edits:
   ```powershell
   git status --short
   ```

### 2) Investigate a Failed Flow Run
1. Provide flow name + run ID to Codex.
2. Codex pulls action-level run details via API/CLI.
3. Codex identifies exact failing action and root cause.
4. If approved, Codex patches canonical flow JSON and deploys.

### 3) Patch + Deploy with Codex
1. Ask Codex to patch specific flow.
2. Codex edits canonical file only.
3. Codex validates JSON/smoke checks.
4. Codex runs `pac solution pack` + `pac solution import`.
5. You re-test and send new run ID.

### 4) Share Changes with Team
1. Commit and push:
   ```powershell
   git add .
   git commit -m "bgv: <summary>"
   git push
   ```
2. Teammate pulls latest:
   ```powershell
   git pull --ff-only
   ```

## How To Push To GitHub (Safe Sequence)
Use this sequence every time you finish a change:

1. Confirm latest baseline:
   ```powershell
   git pull --ff-only
   ```
2. Check what changed:
   ```powershell
   git status --short
   ```
3. Stage only intended files:
   ```powershell
   git add <file1> <file2> ...
   ```
4. Commit with a clear message:
   ```powershell
   git commit -m "bgv: <what changed>"
   ```
5. Push:
   - if working on `master`:
     ```powershell
     git push origin master
     ```
   - if working on a feature branch:
     ```powershell
     git push origin <branch-name>
     ```
6. Verify CI result in GitHub (especially `Linked Docs Guard`).

## End-to-End Delivery: GitHub -> Power Automate -> Live Production
Use this when you want to move changes safely from source control into runtime environments.

### A) From Local To GitHub (source of truth update)
1. Sync and verify:
   ```powershell
   powershell -File scripts/active/bgv_daily_sync.ps1
   pac auth who
   git status --short --branch
   ```
2. Commit and push:
   ```powershell
   git add <intended-files>
   git commit -m "bgv: <change summary>"
   git push origin master
   ```
3. Confirm GitHub checks pass (`Linked Docs Guard` at minimum).

### B) From GitHub To Power Automate (same environment deployment)
This deploys your committed canonical unpacked files.

1. Pull latest:
   ```powershell
   git pull --ff-only
   ```
2. Confirm target identity/environment before deploying:
   ```powershell
   pac auth who
   ```
3. (Recommended) Export backup of current environment state before import:
   ```powershell
   pac solution export --name BGV_System --path .\artifacts\exports\BGV_System_predeploy_backup.zip --managed false --overwrite
   ```
4. Pack from canonical unpacked source:
   ```powershell
   pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
   ```
5. Import and publish:
   ```powershell
   pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
   ```
6. Post-deploy smoke check:
   - ensure the 7 `BGV_*` flows are `On`
   - run at least one known test scenario
   - confirm run history has no immediate failures

### C) Promote To Live Production (recommended controlled path)
If production is a different environment, avoid direct ad-hoc edits in production.

1. Confirm production PAC profile/environment:
   ```powershell
   pac auth select --name <PROD_PROFILE>
   pac auth who
   ```
2. Take production backup export first:
   ```powershell
   pac solution export --name BGV_System --path .\artifacts\exports\BGV_System_prod_predeploy_backup.zip --managed false --overwrite
   ```
3. Import approved package to production:
   ```powershell
   pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
   ```
4. Run production smoke tests:
   - one candidate declaration
   - one employer response path
   - verify reminder flows remain healthy
5. Record deployment in `docs/progress.md` (date, package used, result, rollback point).

### Rollback (if production issue found)
Fastest safe rollback:
1. Re-import known good backup package:
   ```powershell
   pac solution import --path .\artifacts\exports\BGV_System_prod_predeploy_backup.zip --publish-changes --force-overwrite
   ```
2. Re-test critical path (`BGV_0` -> `BGV_5`) and confirm recovery.

### UI-only Tasks (keep minimal)
CLI-first remains default. Use portal only for:
- creating/signing-in connection instances
- sharing flows with co-owner permissions
- rebinding broken connection references when needed

## Best Practices Checklist
- Always run `pac auth who` before any PAC command.
- Always sync first (`bgv_daily_sync.ps1`) before editing flows.
- Edit only canonical flow files:
  - `flows/power-automate/unpacked/Workflows/`
- Keep changes minimal and task-focused; avoid broad refactors during production fixes.
- Never commit secrets or `.env`; keep credentials local only.
- When flow JSON changes, update linked docs in the same task:
  - `docs/progress.md` and at least one behavior doc.
- Validate before deploy:
  - JSON parse checks on edited flow files.
  - script syntax checks where applicable.
- Deploy intentionally with pack/import; do not assume local edits are live.
- After test runs, capture and share:
  - flow name
  - run ID
  - failed action
  - error message
- If unsure which account is active or which path is canonical, stop and verify first.

## Linked Documentation Policy (Auto Enforced)
When canonical flow JSON changes, docs must be updated in same change.

Required:
- `docs/progress.md`
- plus at least one behavior doc:
  - `System_SPEC.md`
  - `docs/flows_easy_english.md`
  - `docs/architecture_flows.md`

CI guard:
- `.github/workflows/linked-docs-guard.yml`
- `scripts/active/enforce_linked_docs.py`

## Recommended Prompt Format for Codex
When requesting fixes, include:
- flow name
- run ID
- expected behavior
- current failure behavior
- whether Codex should deploy after patch

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
