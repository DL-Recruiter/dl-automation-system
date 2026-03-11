# VS Code and Microsoft 365 Toolchain Guide (BGV)

Updated: 2026-03-11

This guide is the end-to-end setup reference for collaborators working on
the BGV project from VS Code.

Use it for:
- new-machine setup
- extension and CLI installation
- daily sign-in checks
- Codex-assisted authentication
- collaborator onboarding before flow or SharePoint migration work

This guide complements, not replaces:
- `docs/collaboration_setup_guide.md`
- `docs/ms365_authentication_runbook.md`

## 1) BGV Baseline

Repository:
- `C:\DLR Automation VS Studio Code\bgv_project`
- Git remote:
  `https://github.com/DL-Recruiter/dl-automation-system.git`

Power Platform environment:
- URL: `https://orgde64dc49.crm5.dynamics.com/`

Current SharePoint sites:
- current site:
  `https://dlresourcespl88.sharepoint.com/sites/dlrespl`
- migration target:
  `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570`

Current tenant:
- tenant id: `38597470-4753-461a-837f-ad8c14860b22`

Common accounts:
- `edwin.teo@dlresources.com.sg` = development/admin
- `recruitment@dlresources.com.sg` = operations/collaborator

## 2) Approved Toolchain

### 2.1 VS Code extensions

Required for normal BGV work:
- `microsoft-isvexptools.powerplatform-vscode`
  Power Platform Tools for solution-aware work and PAC integration.
- `ms-vscode.powershell`
  Needed for repo scripts, PnP PowerShell, and migration scripting.
- `adamwojcikit.cli-for-microsoft-365-extension`
  Helps with `m365` command discovery and usage from VS Code.
- `adamwojcikit.pnp-powershell-extension`
  Helps with PnP PowerShell command discovery and SharePoint scripting.

Required when touching Azure Functions or Azure resources:
- `ms-azuretools.vscode-azurefunctions`
- `ms-azuretools.vscode-azureresourcegroups`
- `ms-azuretools.vscode-azurestorage`
- `ms-vscode.azurecli`
- `ms-dotnettools.csharp`
- `ms-dotnettools.csdevkit`
- `ms-dotnettools.vscode-dotnet-runtime`

Helpful but optional:
- `daniellaskewitz.power-platform-connectors`
- `richardwilson.powerplatform-connector-linter`

### 2.2 Terminal tools and modules

Required:
- `git`
- `pac`
- `az`
- `node` and `npm`
- `m365`
- `PnP.PowerShell`
- `Microsoft.Graph`

Required when working on the Azure Function project:
- `.NET SDK 8+`
- `Azure Functions Core Tools`
- `py` / Python for repo scripts and tests

## 3) Current validated setup on Edwin machine

This is the locally verified baseline as of 2026-03-11.

VS Code extensions:
- `microsoft-isvexptools.powerplatform-vscode@2.0.133`
- `daniellaskewitz.power-platform-connectors@0.4.1`
- `richardwilson.powerplatform-connector-linter@1.0.8`
- `ms-vscode.powershell@2025.4.0`
- `adamwojcikit.cli-for-microsoft-365-extension@3.0.60`
- `adamwojcikit.pnp-powershell-extension@3.0.61`
- `ms-azuretools.vscode-azurefunctions@1.20.3`
- `ms-azuretools.vscode-azureresourcegroups@0.12.2`
- `ms-azuretools.vscode-azurestorage@0.17.1`
- `ms-vscode.azurecli@0.6.0`
- `ms-dotnettools.csharp@2.120.3`
- `ms-dotnettools.csdevkit@2.10.3`
- `ms-dotnettools.vscode-dotnet-runtime@3.0.0`

Terminal tools and modules:
- `pac` = `2.2.1`
- `az` = `2.83.0`
- `func` = `4.6.0`
- `m365` = `11.5.0`
- `PnP.PowerShell` = `3.1.0`
- `Microsoft.Graph` = `2.35.1`
- `PowerShell` = `7.5.4`
- `Python` = `3.14.3`
- `.NET SDK` = `10.0.104`

Note:
- the repo Azure Function project is pinned by
  `functions/bgv-docx-parser/global.json` to the `.NET 8` line, so
  collaborators should still install a `.NET 8` SDK even if a newer SDK
  is present.

## 4) One-time machine setup

### 4.1 Install VS Code extensions

Run from a terminal:

```powershell
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension microsoft-isvexptools.powerplatform-vscode
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-vscode.powershell
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension adamwojcikit.cli-for-microsoft-365-extension
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension adamwojcikit.pnp-powershell-extension
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-azuretools.vscode-azurefunctions
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-azuretools.vscode-azureresourcegroups
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-azuretools.vscode-azurestorage
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-vscode.azurecli
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-dotnettools.csharp
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-dotnettools.csdevkit
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension ms-dotnettools.vscode-dotnet-runtime
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension daniellaskewitz.power-platform-connectors
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension richardwilson.powerplatform-connector-linter
```

Then restart VS Code once.

### 4.2 Install CLI tools and PowerShell modules

Install `CLI for Microsoft 365`:

```powershell
npm install -g @pnp/cli-microsoft365@latest
```

Install PowerShell modules:

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
```

### 4.3 Tools that should already exist or be installed from official Microsoft installers

Verify these from a terminal:

```powershell
git --version
pac help
az version
func --version
py --version
dotnet --version
```

Install or repair them if missing:
- `git`
- `pac`
- `az`
- `func`
- `py`
- `.NET SDK 8`

### 4.4 Verify the final setup

```powershell
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --list-extensions --show-versions
Get-Command pac, az, func, m365, git -ErrorAction SilentlyContinue
Get-Module -ListAvailable PnP.PowerShell, Microsoft.Graph
```

## 5) Extension-to-auth mapping

The VS Code extensions do not usually maintain their own independent
sign-in state. They rely on CLI or module auth contexts.

- Power Platform Tools -> `pac`
- Azure CLI extension -> `az`
- Azure Functions / Azure Resources / Azure Storage extensions ->
  Azure account and subscription context
- CLI for Microsoft 365 extension -> `m365`
- PnP PowerShell extension -> `Connect-PnPOnline` session
- C# / .NET extensions -> no cloud sign-in required for local builds

This matters because Codex should verify the CLI or module auth state,
not just whether the extension icon looks signed in.

## 6) What the human user must still do

Codex can help with setup and can start sign-in commands, but cannot do
these parts for you:
- complete browser login pages
- enter MFA codes
- approve tenant consent prompts
- approve app registration permissions
- choose the correct Microsoft account in the browser if multiple are cached
- verify UI-only connector bindings in Power Automate when required

In practice, Codex can get you to the login prompt and then verify the
result after you finish the browser step.

## 7) Standard Codex-assisted sign-in SOP

Use this every time you start work, especially before migration or
deployment work.

### 7.1 Standard start-of-day Codex prompt

Use a prompt like:

`Run repo and auth preflight for BGV. Check git, pac, az, m365, PnP, and Microsoft Graph. If anything is unsigned or on the wrong account, start the correct login command and tell me what browser/device step I need to complete.`

### 7.2 What Codex should check first

Codex should run:

```powershell
Get-Location
git remote -v
git status --short --branch
pac auth who
az account show
m365 status
Get-PnPConnection
Get-MgContext
```

Expected repo:
- path = `C:\DLR Automation VS Studio Code\bgv_project`
- remote = `https://github.com/DL-Recruiter/dl-automation-system.git`

### 7.3 Tool-by-tool sign-in decision rules

#### PAC CLI

Status check:

```powershell
pac auth who
pac auth list
```

If wrong profile is already present:

```powershell
pac auth select --name BGV_EDWIN
# or
pac auth select --name BGV_RECRUITMENT
pac auth who
```

If no correct profile exists:

```powershell
pac auth create --name BGV_EDWIN --deviceCode --environment https://orgde64dc49.crm5.dynamics.com/
```

Human action:
- complete the device-code/browser prompt

Codex follow-up:
- rerun `pac auth who`

#### Azure CLI

Status check:

```powershell
az account show
```

If signed out:

```powershell
az login
```

If the wrong subscription is active:

```powershell
az account list -o table
az account set --subscription "<subscription name or id>"
az account show
```

Human action:
- complete browser login if prompted

Codex follow-up:
- rerun `az account show`

#### CLI for Microsoft 365

Status check:

```powershell
m365 status
```

If signed out:

```powershell
m365 login --authType browser
```

If the tenant blocks the default CLI app or requires a custom app:

```powershell
m365 setup
```

Human action:
- complete browser login and consent if prompted

Codex follow-up:
- rerun `m365 status`

#### PnP PowerShell

Status check:

```powershell
Get-PnPConnection
```

If no active connection exists, set the local session values first:

```powershell
$env:SHAREPOINT_SITE_URL = "https://dlresourcespl88.sharepoint.com/sites/dlrespl"
$env:PNP_CLIENT_ID = "3e59bbcc-3e14-4837-b6e0-0a1870286f31"
$env:PNP_TENANT_ID = "38597470-4753-461a-837f-ad8c14860b22"
```

Then connect:

```powershell
Connect-PnPOnline `
  -Url $env:SHAREPOINT_SITE_URL `
  -Interactive `
  -ClientId $env:PNP_CLIENT_ID `
  -Tenant $env:PNP_TENANT_ID
```

Human action:
- complete the interactive sign-in and consent

Codex follow-up:
- rerun `Get-PnPConnection`

#### Microsoft Graph PowerShell

Graph is optional for normal BGV work and should be connected only when
Graph commands are actually needed.

Status check:

```powershell
Get-MgContext
```

For inventory or read-only validation:

```powershell
Connect-MgGraph -NoWelcome -Scopes "User.Read","Sites.Read.All","Files.Read.All","Group.Read.All"
```

For migration write operations, request broader scopes only when needed:

```powershell
Connect-MgGraph -NoWelcome -Scopes "User.Read","Sites.ReadWrite.All","Files.ReadWrite.All","Group.Read.All"
```

Human action:
- complete the browser sign-in and consent

Codex follow-up:
- rerun `Get-MgContext`

Rule:
- prefer read-only scopes first
- request write scopes only for the task that actually needs them

## 8) Daily preflight sequence

This is the standard safe sequence before real work:

1. Open the BGV repo in VS Code.
2. Ask Codex to run repo and auth preflight.
3. Let Codex report which tools are signed in and which are not.
4. If any login is needed, let Codex start the login command.
5. Complete the browser or device-code step yourself.
6. Let Codex rerun the status command.
7. Only after auth is confirmed:
   - run `scripts/active/bgv_daily_sync.ps1`
   - inspect diffs
   - start editing or migration work

## 9) Collaborator access checklist

Before a colleague can actually work in this repo, they need:
- GitHub access to `DL-Recruiter/dl-automation-system`
- access to the Power Platform environment
- permission to view/export/import the `BGV_System` solution
- access to the current SharePoint site and, if migrating, the target site
- access to the 3 BGV SharePoint lists and `BGV Records`
- access to the Teams team/channel used by `BGV_3`, `BGV_5`, and `BGV_6`
- flow co-owner rights if they need portal-side validation
- valid connector permissions for:
  - SharePoint
  - Microsoft Forms
  - Office 365 Outlook
  - Microsoft Teams
  - Word Online (Business), if using the existing doc template action

## 10) Recommended Codex prompts

Machine setup:
- `Check my BGV VS Code toolchain. Verify all relevant extensions, CLI tools, PowerShell modules, and versions. Install anything missing and log the result in docs/progress.md.`

Daily sign-in:
- `Run BGV auth preflight. Check pac, az, m365, PnP, and Graph. If login is needed, start the correct command and tell me what I need to complete in the browser.`

Migration preparation:
- `Check whether my toolchain is ready for SharePoint and flow migration from dlrespl to DLRRecruitmentOps570. Verify pac, m365, PnP, Graph, az, and function tooling.`

## 11) Troubleshooting

`code.cmd` not found:
- use the full path
  `C:\Users\<user>\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd`

`m365` not found:
- reinstall with `npm install -g @pnp/cli-microsoft365@latest`
- restart the terminal

`Connect-MgGraph` not found:
- reinstall `Microsoft.Graph`
- restart the terminal

`Connect-PnPOnline` not found:
- reinstall `PnP.PowerShell`
- restart the terminal

Power Platform Tools installed but `pac` missing:
- reopen VS Code and terminal
- if still missing, repair PAC CLI from the extension or install it from
  the official Microsoft Power Platform tooling path

PnP connection works for one site but not another:
- update `$env:SHAREPOINT_SITE_URL`
- reconnect with `Connect-PnPOnline`

Wrong account in browser:
- sign out from the wrong tenant session in the browser, or use a
  private window for the login command

## 12) Official references

- Power Platform Tools:
  https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.powerplatform-vscode
- Azure Functions extension:
  https://learn.microsoft.com/azure/azure-functions/create-first-function-vs-code-csharp
- CLI for Microsoft 365 install:
  https://pnp.github.io/cli-microsoft365/user-guide/installing-cli/
- CLI for Microsoft 365 VS Code extension:
  https://marketplace.visualstudio.com/items?itemName=AdamWójcikIT.cli-for-microsoft-365-extension
- PnP PowerShell install:
  https://pnp.github.io/powershell/articles/installation.html
- PnP PowerShell VS Code extension:
  https://marketplace.visualstudio.com/items?itemName=AdamWójcikIT.pnp-powershell-extension
- Microsoft Graph PowerShell install:
  https://learn.microsoft.com/powershell/microsoftgraph/installation
- PowerShell VS Code extension:
  https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell
- Azure Storage extension:
  https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurestorage
