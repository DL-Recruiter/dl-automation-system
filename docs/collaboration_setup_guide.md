# BGV Collaboration Setup Guide (Edwin + Recruitment)

Updated: 2026-03-10

This guide explains how to work safely on BGV flows with two accounts:
- `edwin.teo@dlresources.com.sg` (development/admin)
- `recruitment@dlresources.com.sg` (operations/collaborator)

## 1) One-Time Setup on Edwin Machine

Before any Git or PAC command, confirm you are in the correct BGV repo.
This prevents accidental work in the wrong GitHub project when multiple
repos are open in VS Code or different terminals.

### 1.1 Confirm repo and branch
```powershell
Get-Location
git remote -v
git status --short --branch
```

Expected:
- local path is `C:\DLR Automation VS Studio Code\bgv_project`
- remote points to `https://github.com/DL-Recruiter/dl-automation-system.git`
- branch is `master`
- working tree is clean

If any of these checks do not match, stop and open the correct repo
folder before running `git pull`, `git commit`, `git push`,
`pac solution ...`, or the daily sync script.

### 1.2 Confirm active PAC identity before any changes
```powershell
pac auth list
pac auth who
```

If identity is wrong, switch it:
```powershell
pac auth select --name <PROFILE_NAME>
pac auth who
```

If `pac auth who` shows the correct user but export commands still fail with `No active environment set`, the selected
profile is not currently bound to an active environment. Reselect a profile created with `--environment` or pass the
explicit environment URL to the sync/export commands.

### 1.3 Create profile names (optional but recommended)
Use device code sign-in so no password is stored in scripts:
```powershell
pac auth create --name BGV_EDWIN --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
pac auth create --name BGV_RECRUITMENT --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
```

Important:
- Sign in as `edwin.teo@...` for `BGV_EDWIN`.
- Sign in as `recruitment@...` for `BGV_RECRUITMENT`.
- After creation, verify with `pac auth list` (check `User` column, not just profile name).

## 2) Canonical Flow Files (Source Control Rule)

Edit only:
- `flows/power-automate/unpacked/Workflows/`

Treat as read-only duplicates:
- `power-automate/`
- root-level exported `BGV_*.json` files (if added later)

Why:
- avoids changing stale copies
- keeps Codex and teammates editing the same files

## 3) Daily Team Workflow (Safe Collaboration Loop)

### Step A: Pull latest before work
```powershell
Get-Location
git remote -v
git status --short --branch
git pull --ff-only
```

Only continue if the repo path and remote match the BGV project.

### Step B: Export and unpack latest tenant solution
```powershell
pac auth who
pac solution export --environment https://orgde64dc49.crm5.dynamics.com/ --name BGV_System --path .\artifacts\exports\BGV_System_unmanaged.zip --managed false --overwrite
pac solution unpack --zipfile .\artifacts\exports\BGV_System_unmanaged.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
```

### One-command daily sync (recommended)
Use the helper script to run identity check + pull + export + unpack:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

Optional with tests:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/ -RunTests
```

If `python` is not available in PATH, pass full executable path:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/ -RunTests -PythonExe C:\path\to\python.exe
```

After sync, review the resulting flow diff before updating behavior docs:
```powershell
git diff -- flows/power-automate/unpacked/Workflows/
```

If the diff only shows `No newline at end of file`, treat it as formatting-only export noise rather than a flow logic
change.

### Step C: Edit canonical flow files (manual or Codex)
- Only edit files under `flows/power-automate/unpacked/Workflows/`.

### Step D: Validate locally
```powershell
py -m pytest -q tests
```

Optional verification script:
```powershell
py scripts/active/verify_flow_runs.py
```

### Step E: Commit and push
```powershell
git status
git add .
git commit -m "bgv: <short change summary>"
git push
```

## 4) Deploy Edited Flows Back to Environment

```powershell
pac auth who
pac solution pack --zipfile .\artifacts\exports\BGV_System_unmanaged.repack.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
pac solution import --path .\artifacts\exports\BGV_System_unmanaged.repack.zip --publish-changes --force-overwrite
```

## 5) Sharing for Recruitment Account (UI Steps)

These steps are UI-bound and cannot be completed fully via CLI:
1. In Power Automate, open each active `BGV_*` flow.
2. Share flow with `recruitment@dlresources.com.sg` as `Co-owner`.
3. Confirm `recruitment@...` can access required connectors:
   - SharePoint
   - Office 365 Outlook
   - Forms
   - Teams
   - Word Online (if used)
4. Rebind connection references if the current owner-only connection is invalid.
5. Run one smoke test under recruitment account and record result.

## 6) SharePoint List Admin Auth (PnP PowerShell)

Use this only when you need to create/modify SharePoint lists directly from terminal.

### 6.1 One-time tenant app registration status
- App registration method: `Register-PnPEntraIDAppForInteractiveLogin`
- Current app display name: `BGV-PnP-Automation`
- Current app client id: `3e59bbcc-3e14-4837-b6e0-0a1870286f31`

### 6.2 Local env placeholders
Set locally (do not commit secrets):
- `PNP_CLIENT_ID`
- `PNP_TENANT_ID`

### 6.3 Connect command pattern
```powershell
Connect-PnPOnline `
  -Url $env:SHAREPOINT_SITE_URL `
  -Interactive `
  -ClientId $env:PNP_CLIENT_ID `
  -Tenant $env:PNP_TENANT_ID
```

### 6.4 Verify PnP session
```powershell
Get-PnPConnection
```

## 7) Troubleshooting Quick Guide

### Problem: profile name exists but wrong user
- Run:
```powershell
pac auth list
pac auth who
```
- Fix by deleting and recreating with device code:
```powershell
pac auth delete --name <PROFILE_NAME>
pac auth create --name <PROFILE_NAME> --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
```

### Problem: flow edits disappear after teammate update
- Root cause: edits were made in non-canonical duplicate paths.
- Fix: revert duplicate-path edits and reapply in canonical folder only.

### Problem: `pac solution export` says no active environment is set
- Check current PAC profile:
```powershell
pac auth list
pac auth who
```
- Fix by selecting the environment-bound profile or passing the explicit environment URL:
```powershell
pac auth select --name <PROFILE_NAME>
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

### Problem: import succeeds but flow fails at runtime
- Check connection references and owner permissions first.
- Then inspect run history and connector authorization states.
