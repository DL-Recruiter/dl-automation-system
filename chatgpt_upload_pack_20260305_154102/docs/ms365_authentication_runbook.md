# MS365 Authentication Runbook (BGV)

Updated: 2026-03-03

This document is the single reference for authentication setup across:
- Power Platform (`pac`)
- Azure (`az`)
- SharePoint list administration (PnP PowerShell)
- Microsoft 365 CLI (`m365`, optional)

Use this when setting up a new machine or re-establishing access.

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

## 3) One-Time Setup Per Machine

### 3.1 Verify tool availability
```powershell
pac auth list
az account show
Get-Module -ListAvailable PnP.PowerShell
```

Optional:
```powershell
m365 status
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

## 4) Daily Preflight Checklist

Run before editing/deploying flows:
```powershell
pac auth who
az account show
```

If touching SharePoint lists directly:
```powershell
Get-PnPConnection
```

If using m365 CLI:
```powershell
m365 status
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

PnP fails due missing app context:
- Verify `PNP_CLIENT_ID`, `PNP_TENANT_ID`, and `SHAREPOINT_SITE_URL`.
- Re-run `Connect-PnPOnline` with `-Interactive -ClientId -Tenant`.

`m365` command not found:
- Install `@pnp/cli-microsoft365` globally and reopen terminal.

