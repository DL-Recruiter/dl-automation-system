# BGV Collaboration Setup Guide (Edwin + Recruitment)

Updated: 2026-03-02

This guide explains how to work safely on BGV flows with two accounts:
- `edwin.teo@dlresources.com.sg` (development/admin)
- `recruitment@dlresources.com.sg` (operations/collaborator)

## 1) One-Time Setup on Edwin Machine

### 1.1 Confirm repo and branch
```powershell
git -C C:\bgv_project remote -v
git -C C:\bgv_project branch --show-current
git -C C:\bgv_project status --short --branch
```

Expected:
- remote points to `https://github.com/DL-Recruiter/dl-automation-system.git`
- branch is `master`
- working tree is clean

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
cd C:\bgv_project
git pull --ff-only
```

### Step B: Export and unpack latest tenant solution
```powershell
pac auth who
pac solution export --name BGV_System --path .\artifacts\exports\BGV_System_unmanaged.zip --managed false --overwrite
pac solution unpack --zipfile .\artifacts\exports\BGV_System_unmanaged.zip --folder .\flows\power-automate\unpacked --packagetype Unmanaged --allowDelete true --allowWrite true --clobber true
```

### One-command daily sync (recommended)
Use the helper script to run identity check + pull + export + unpack:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1
```

Optional with tests:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -RunTests
```

If `python` is not available in PATH, pass full executable path:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -RunTests -PythonExe C:\path\to\python.exe
```

### Step C: Edit canonical flow files (manual or Codex)
- Only edit files under `flows/power-automate/unpacked/Workflows/`.

### Step D: Validate locally
```powershell
python -m pytest -q tests
```

Optional verification script:
```powershell
python scripts/active/verify_flow_runs.py
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

## 6) Troubleshooting Quick Guide

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

### Problem: import succeeds but flow fails at runtime
- Check connection references and owner permissions first.
- Then inspect run history and connector authorization states.
