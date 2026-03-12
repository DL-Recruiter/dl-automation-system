# DL Automation System (BGV)

This repository is the source-controlled working copy of the
`BGV_System` Power Automate solution.

Use it when you need to:

- sync the latest BGV flows from Power Automate into Git
- inspect or patch the canonical unpacked flow files
- deploy approved changes back into the environment
- keep flow logic and supporting documentation aligned

## What The BGV Automation Does

The BGV process has two main tracks:

- candidate authorization
- employer verification

At a high level, the system works like this:

1. `BGV_0_CandidateDeclaration` starts the case when a candidate submits
   the declaration form.
1. The system creates candidate records, employer request rows,
   normalized form-data rows, and the authorization document.
1. `BGV_1_Detect_Authorization_Signature` checks whether the candidate
   has signed the authorization form.
1. `BGV_2_Postsignature` removes broad sharing after the signed form is
   confirmed.
1. `BGV_4_SendToEmployer_Clean` sends the signed authorization and the
   prefilled employer verification form to HR.
1. `BGV_5_Response1` processes the employer's reply, updates records,
   and alerts recruiters when needed.
1. `BGV_3_AuthReminder_5Days` and
   `BGV_6_HRReminderAndEscalation` chase delayed candidate or employer
   responses.

The main working data locations are:

- `BGV_Candidates` for candidate progress
- `BGV_Requests` for employer request tracking
- `BGV_FormData` for normalized Form 1 and Form 2 values
- `BGV Records` for authorization documents and candidate files

For a beginner-friendly explanation of what each SharePoint list is for
and what its important columns mean, start with
`docs/sharepoint_list_user_guide.md`.

## If You Only Remember Five Rules

1. Always verify you are in the correct repo before any Git or PAC
   command.
1. Always sync first before editing anything.
1. Always run `pac auth who` before any PAC command.
1. Edit only the canonical flow files in
   `flows/power-automate/unpacked/Workflows/`.
1. Local JSON edits are not live until you `pack` and `import` the
   solution back into Power Automate.

## Before Any Git Or PAC Command, Verify The Repo

This matters because you may have more than one GitHub repo open in VS
Code or in different terminals. If you run `git pull`, `git commit`,
`git push`, `pac solution ...`, or the daily sync script in the wrong
folder, you will update the wrong project.

Run these checks first:

```powershell
Get-Location
git remote -v
git status --short --branch
```

What you should expect in this project:

- local path should be `C:\DLR Automation VS Studio Code\bgv_project`
- `origin` should be
  `https://github.com/DL-Recruiter/dl-automation-system.git`
- working branch is usually `master`

Only continue if all three checks match this BGV project.

If any check does not match:

1. stop immediately
1. do not run `git pull`, `git commit`, `git push`, `pac solution ...`,
   or `powershell -File scripts/active/bgv_daily_sync.ps1`
1. open the correct repo folder first
1. rerun the three checks

Good prompt examples for Codex:

- `Work in C:\DLR Automation VS Studio Code\bgv_project`
- `Use repo DL-Recruiter/dl-automation-system on master`
- `Before pushing, confirm repo path, remote, and branch`

## Start Of Day

First verify the repo:

```powershell
Get-Location
git remote -v
git status --short --branch
```

Then run this command before editing, testing, or asking Codex to patch
a flow:

```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

Then confirm your identity and working tree:

```powershell
pac auth who
git status --short --branch
```

If `pac auth who` shows the correct user but `pac solution export` fails
with `No active environment set`, either:

- reselect a PAC profile created with `--environment`
- rerun the sync command with
  `-EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/`

## What The Daily Sync Script Does

`scripts/active/bgv_daily_sync.ps1` is the standard start-of-day refresh
script.

It does this in order:

1. checks that `git` and `pac` are available
1. confirms the repo path is valid
1. shows the active Power Platform login with `pac auth who`
1. runs `git pull --ff-only`
1. exports `BGV_System` into
   `artifacts/exports/BGV_System_unmanaged.zip`
1. unpacks the solution into `flows/power-automate/unpacked/`
1. optionally runs tests if `-RunTests` is passed

It does not:

- commit changes
- push to GitHub
- deploy changes back into Power Automate

Common command variants:

```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/ -RunTests
```

```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/ -RunTests -PythonExe C:\path\to\python.exe
```

After sync, review the diff before assuming the behavior changed:

```powershell
git diff -- flows/power-automate/unpacked/Workflows/
```

If the diff only shows end-of-file newline changes such as
`No newline at end of file`, treat that as export formatting noise
rather than a logic change.

## One-Time Setup

1. Open the repo in VS Code at
   `C:\DLR Automation VS Studio Code\bgv_project`.
1. If this is your first time in the project, start with:
   - `docs/first_time_and_daily_sop_guide.md`
1. For the full extension, CLI, module, and sign-in setup guide, read:
   - `docs/vscode_ms365_toolchain_guide.md`
   - `docs/ms365_authentication_runbook.md`
1. Make sure these tools exist in the terminal:

   - `git`
   - `pac`
   - `py` or `python` for tests and helper scripts

1. Confirm PAC identity:

   ```powershell
   pac auth who
   ```

1. If needed, create or reselect the intended PAC profile.

The two user accounts normally involved are:

- `edwin.teo@dlresources.com.sg`
- `recruitment@dlresources.com.sg`

## Canonical Files You May Edit

Edit cloud flows only in:

- `flows/power-automate/unpacked/Workflows/`

Treat these as read-only duplicates unless explicitly requested:

- `power-automate/`
- root `BGV_*.json` exports if they exist

Why this matters:

- the unpacked workflow files are the source-controlled version used for
  review and deployment
- editing duplicate exports creates confusion and makes later syncs
  overwrite your work
- the canonical BGV flow JSON is now portability-tokenized for the site
  migration with `__BGV_*__` markers
- do not pack the raw tokenized folder for green deployment; first run
  `scripts/active/bgv_build_deployment_settings.ps1 -MaterializeTo <folder>`
  and pack the materialized copy instead

## Common User Tasks

### 1) Start Work Safely

1. Run the daily sync command.
1. Run `pac auth who`.
1. Check the working tree:

   ```powershell
   git status --short
   ```

1. If the sync introduced real logic changes from the cloud, review them
   before editing.

### 2) Ask Codex To Investigate A Failed Flow

Give Codex:

- the flow name
- the run ID
- the expected behavior
- the current failure behavior
- whether Codex should deploy after patching

Codex can then:

- inspect run details
- identify the failing action
- patch the canonical JSON
- pack and import the updated solution if requested

### 3) Patch And Deploy A Flow

Standard sequence:

1. sync first
1. patch only the canonical file
1. validate the JSON
1. pack the solution
1. import the solution
1. rerun a live test

Deployment commands:

```powershell
pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
```

### 4) Share Changes With Teammates

Commit and push only the intended files:

```powershell
git status --short
git add <file1> <file2> ...
git commit -m "bgv: <short summary>"
git push
```

Teammates should pull before starting:

```powershell
git pull --ff-only
```

## Run History Utilities

Single-flow verification:

```powershell
py scripts/active/verify_flow_runs.py
```

All canonical flows in one report:

```powershell
py scripts/active/pull_all_flow_runs.py
```

Default output file:

- `out/flow_run_history_latest.json`

Use these scripts when you need to confirm whether a deployment worked
or inspect recent run behavior without opening each flow manually.

## GitHub Workflow

Use this sequence whenever you finish a change:

1. verify the repo first

   ```powershell
   Get-Location
   git remote -v
   git status --short --branch
   ```

1. confirm latest baseline

   ```powershell
   git pull --ff-only
   ```

1. check what changed

   ```powershell
   git status --short
   ```

1. stage only the intended files

   ```powershell
   git add <file1> <file2> ...
   ```

1. commit with a clear message

   ```powershell
   git commit -m "bgv: <what changed>"
   ```

1. push

   ```powershell
   git push origin master
   ```

1. verify GitHub checks, especially `Linked Docs Guard`

## End-To-End Delivery

Use this when you need to move changes from source control into the live
Power Automate environment.

### A) Local To GitHub

1. Sync and verify:

   ```powershell
   powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
   pac auth who
   git status --short --branch
   ```

1. Commit and push:

   ```powershell
   git add <intended-files>
   git commit -m "bgv: <change summary>"
   git push origin master
   ```

1. Confirm GitHub checks pass.

### B) GitHub To Power Automate

This applies the committed canonical unpacked files back into the same
environment.

1. Pull latest:

   ```powershell
   git pull --ff-only
   ```

1. Confirm target identity:

   ```powershell
   pac auth who
   ```

1. Export a backup before import:

   ```powershell
   pac solution export --name BGV_System --path .\artifacts\exports\BGV_System_predeploy_backup.zip --managed false --overwrite
   ```

1. Pack from canonical source:

   ```powershell
   pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
   ```

1. Import and publish:

   ```powershell
   pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
   ```

1. Smoke check:

   - ensure the 7 `BGV_*` flows are `On`
   - run at least one known test scenario
   - confirm run history has no immediate failures

### C) Promote To Production

If production is a different environment, avoid editing directly in
production.

1. Select the production PAC profile:

   ```powershell
   pac auth select --name <PROD_PROFILE>
   pac auth who
   ```

1. Export a production backup:

   ```powershell
   pac solution export --name BGV_System --path .\artifacts\exports\BGV_System_prod_predeploy_backup.zip --managed false --overwrite
   ```

1. Import the approved package:

   ```powershell
   pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
   ```

1. Run smoke tests:

   - one candidate declaration
   - one employer response path
   - reminder flow health checks

1. Record the deployment in `docs/progress.md`.

### Rollback

If production has a problem, re-import the last known good backup:

```powershell
pac solution import --path .\artifacts\exports\BGV_System_prod_predeploy_backup.zip --publish-changes --force-overwrite
```

Then retest the critical path from `BGV_0` through `BGV_5`.

## UI-Only Tasks

CLI-first remains the default.

Use the Power Automate portal only for:

- creating or signing into connection instances
- sharing flows with co-owner permissions
- rebinding broken connection references when needed

After UI-only changes, sync the solution back into this repo so Git
stays current.

## SharePoint Site Migration

The migration from:

- blue/source: `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
- green/target: `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`

is implemented in this repo as a blue/green, tokenized-source workflow.

Key rules:

- canonical flow JSON under `flows/power-automate/unpacked/Workflows/`
  must stay tokenized
- `scripts/active/check_bgv_portability.py` fails if old site/list/template/
  form/team/mailbox literals re-enter the canonical flow files
- `scripts/active/bgv_build_deployment_settings.ps1` generates:
  - PAC connection settings JSON
  - token values JSON
  - optional materialized flow folder for pack/import

Typical migration sequence:

1. preflight inventory:

   ```powershell
   pac auth who
   powershell -File scripts/active/bgv_migration_inventory.ps1
   ```

1. prepare target schema and upload the Word template:

   ```powershell
   powershell -File scripts/active/bgv_ensure_target_schema.ps1
   ```

1. generate deployment inputs for test or prod:

   ```powershell
   powershell -File scripts/active/bgv_build_deployment_settings.ps1 -EnvironmentName test -MaterializeTo .\out\materialized\bgv_green_test
   ```

1. pack/import from the materialized folder, not from the tokenized
   canonical source:

   ```powershell
   pac solution pack --zipfile .\artifacts\exports\BGV_System_Green_test.zip --folder .\out\materialized\bgv_green_test --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
   ```

1. move closed history first, then validate:

   ```powershell
   powershell -File scripts/active/bgv_copy_site_data.ps1 -Mode ClosedHistory
   powershell -File scripts/active/bgv_validate_target_migration.ps1 -Mode ClosedHistory
   ```

1. after cutover, drain remaining legacy-open cases:

   ```powershell
   powershell -File scripts/active/bgv_copy_site_data.ps1 -Mode LegacyDrain
   powershell -File scripts/active/bgv_validate_target_migration.ps1 -Mode LegacyDrain
   ```

Use these supporting files during the migration:

- `flows/power-automate/deployment-settings/test.settings.template.json`
- `flows/power-automate/deployment-settings/prod.settings.template.json`
- `.env.example` for optional shell overrides of `BGV_*` token values
- `docs/architecture_flows.md` and `System_SPEC.md` for the portability
  contract and script responsibilities

## Best Practices

- Always run `pac auth who` before any PAC command.
- Always sync first before editing flows.
- If sync fails with `No active environment set`, rerun with
  `-EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/` or reselect
  the correct PAC profile.
- Edit only canonical workflow files in
  `flows/power-automate/unpacked/Workflows/`.
- Keep changes small and task-focused.
- Never commit `.env`, secrets, or tokens.
- When flow JSON changes, update `docs/progress.md` and at least one
  linked behavior document in the same task.
- Validate before deploy with JSON checks, script checks, or focused
  tests.
- Do not assume local edits are live until the solution is packed and
  imported.
- If you are unsure which account or environment is active, stop and
  verify first.

## Linked Documentation Policy

When canonical flow JSON changes, the same change must also update:

- `docs/progress.md`
- plus at least one behavior doc:
  - `System_SPEC.md`
  - `docs/flows_easy_english.md`
  - `docs/architecture_flows.md`

CI guard:

- `.github/workflows/linked-docs-guard.yml`
- `scripts/active/enforce_linked_docs.py`

## Recommended Prompt Format For Codex

When requesting a fix, include:

- flow name
- run ID
- expected behavior
- current failure behavior
- whether Codex should deploy after patching

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
- `docs/sharepoint_list_user_guide.md`
- `docs/flows_easy_english.md`
- `docs/architecture_flows.md`
- `docs/progress.md`
