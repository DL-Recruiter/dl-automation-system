# MS365 Authentication Runbook (BGV)

Updated: 2026-03-10

This document is the single reference for authentication setup across:
- Power Platform (`pac`)
- Azure (`az`)
- SharePoint list administration (PnP PowerShell)
- Microsoft 365 CLI (`m365`, optional)
- Microsoft Graph PowerShell (`Microsoft.Graph`, optional)

Use this when setting up a new machine or re-establishing access.

For the full VS Code extension + CLI/module setup workflow, see:
- `docs/vscode_ms365_toolchain_guide.md`

## 1) Shared Baseline Values

- Tenant ID: `38597470-4753-461a-837f-ad8c14860b22`
- Power Platform environment URL: `https://orgde64dc49.crm5.dynamics.com/`
- SharePoint site URL: set local `SHAREPOINT_SITE_URL` per project/site
- PnP interactive app registration method:
  - `Register-PnPEntraIDAppForInteractiveLogin`
- PnP app display name:
  - `BGV-PnP-Automation`
- PnP app client id:
  - `3e59bbcc-3e14-4837-b6e0-0a1870286f31`

Do not store passwords/secrets in repo files.

## 2) Authentication Contexts (Important)

`pac` auth:
- Controls solution export/pack/import and Dataverse operations.
- Used for Power Automate source-control and deployment workflow.

Power Automate runtime connector auth:
- Flow actions run under connector connection references (for example `shared_sharepointonline`).
- This is separate from terminal `pac` login.

`az` auth:
- Controls Azure subscription and Entra app management tasks.

PnP PowerShell auth:
- Used for direct SharePoint list/site administration from terminal.

`m365` CLI auth (optional):
- Used for Microsoft 365 admin/content tasks through CLI for Microsoft 365.

Microsoft Graph PowerShell auth (optional):
- Used for inventory, validation, and selected scripted Microsoft 365
  tasks when Graph is more appropriate than SharePoint-specific tooling.
- Prefer read-only Graph scopes first and only request write scopes for
  migration tasks that actually need them.

## 3) One-Time Setup Per Machine

### 3.1 Verify tool availability
```powershell
pac auth list
az account show
Get-Module -ListAvailable PnP.PowerShell
Get-Module -ListAvailable Microsoft.Graph
```

Optional:
```powershell
m365 status
Get-MgContext
```

### 3.2 Create/select Power Platform profiles
```powershell
pac auth create --name BGV_EDWIN --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
pac auth create --name BGV_RECRUITMENT --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
pac auth list
```

Before each CLI operation:
```powershell
pac auth who
```

If `pac auth who` shows the expected user but `pac solution export` still reports `No active environment set`, either
reselect the PAC profile created with `--environment` or pass the explicit environment URL into the sync/export
command.

### 3.3 Azure login
```powershell
az login
az account show
```

### 3.4 PnP PowerShell login for SharePoint list administration
Set local env values (example in PowerShell profile or session):
```powershell
$env:SHAREPOINT_SITE_URL = "https://<tenant>.sharepoint.com/sites/<site>"
$env:PNP_CLIENT_ID = "3e59bbcc-3e14-4837-b6e0-0a1870286f31"
$env:PNP_TENANT_ID = "38597470-4753-461a-837f-ad8c14860b22"
```

Connect:
```powershell
Connect-PnPOnline `
  -Url $env:SHAREPOINT_SITE_URL `
  -Interactive `
  -ClientId $env:PNP_CLIENT_ID `
  -Tenant $env:PNP_TENANT_ID
```

Verify:
```powershell
Get-PnPConnection
```

### 3.5 Microsoft 365 CLI (optional)
If not installed:
```powershell
npm install -g @pnp/cli-microsoft365
```

Login and verify:
```powershell
m365 login --authType browser
m365 status
```

### 3.6 Microsoft Graph PowerShell (optional)
If not installed:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
```

Read-only inventory/validation login:
```powershell
Connect-MgGraph -NoWelcome -Scopes "User.Read","Sites.Read.All","Files.Read.All","Group.Read.All"
Get-MgContext
```

If a migration task really needs write access, request it explicitly and
only for that session:
```powershell
Connect-MgGraph -NoWelcome -Scopes "User.Read","Sites.ReadWrite.All","Files.ReadWrite.All","Group.Read.All"
Get-MgContext
```

## 4) Daily Preflight Checklist

Run before editing/deploying flows:
```powershell
Get-Location
git remote -v
git status --short --branch
pac auth who
az account show
m365 status
Get-MgContext
```

Expected for this project:
- local path is `C:\DLR Automation VS Studio Code\bgv_project`
- remote is `https://github.com/DL-Recruiter/dl-automation-system.git`
- branch is usually `master`

If the repo path or remote does not match, stop and open the correct
BGV repo before running Git, PAC, or sync commands.

Recommended sync command for this repo:
```powershell
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

If touching SharePoint lists directly:
```powershell
Get-PnPConnection
```

If using `m365` CLI:
```powershell
m365 status
```

If using Graph PowerShell:
```powershell
Get-MgContext
```

## 5) Account Switching Rules

- `edwin.teo@dlresources.com.sg`: development/admin operations.
- `recruitment@dlresources.com.sg`: operations/co-owner validation.

Switch PAC profile explicitly:
```powershell
pac auth select --name BGV_EDWIN
# or
pac auth select --name BGV_RECRUITMENT
pac auth who
```

Never assume active account by profile name only; always verify `User` in output.

## 6) Security Rules

- Never commit `.env` secrets or client secrets.
- Keep only placeholders in `.env.example`.
- Treat `.gitignore` as confidentiality boundary.
- Avoid sharing access tokens in chat/screenshots.

## 7) Common Issues

Wrong PAC account active:
```powershell
pac auth list
pac auth select --name <profile>
pac auth who
```

Correct user but no active PAC environment:
```powershell
pac auth select --name BGV_EDWIN
# or
pac auth select --name BGV_RECRUITMENT
powershell -File scripts/active/bgv_daily_sync.ps1 -EnvironmentUrl https://orgde64dc49.crm5.dynamics.com/
```

PnP fails due missing app context:
- Verify `PNP_CLIENT_ID`, `PNP_TENANT_ID`, and `SHAREPOINT_SITE_URL`.
- Re-run `Connect-PnPOnline` with `-Interactive -ClientId -Tenant`.

`m365` command not found:
- Install `@pnp/cli-microsoft365` globally and reopen terminal.

`Connect-MgGraph` / `Get-MgContext` not found:
- Install `Microsoft.Graph` for the current user and reopen terminal.

Graph login succeeds but the needed command still fails:
- Check whether the current Graph context has the required scopes.
- Reconnect with the minimal additional scopes required for that task.

