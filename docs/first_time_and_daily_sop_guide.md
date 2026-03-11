# First-Time Setup and Daily SOP Reading Order

Updated: 2026-03-11

This is the document to share first with any collaborator.

Its purpose is simple:
- tell new users which repo documents to read
- tell daily users which document to use for which task
- reduce guessing about where setup ends and daily SOP begins

## 1) If this is your first time on the BGV project

Read these in this order:

1. `README.md`
   Use this first for the repo purpose, canonical flow path, daily sync,
   and deployment workflow.
2. `docs/vscode_ms365_toolchain_guide.md`
   Use this for VS Code extension setup, CLI/module installs, and the
   Codex-assisted sign-in process.
3. `docs/ms365_authentication_runbook.md`
   Use this for tool-by-tool auth commands for `pac`, `az`, `m365`,
   `PnP.PowerShell`, and `Microsoft.Graph`.
4. `docs/collaboration_setup_guide.md`
   Use this for the practical team workflow: sync, export, unpack,
   validate, pack, import, and collaborator sharing rules.
5. `docs/flows_easy_english.md`
   Use this to understand what `BGV_0` to `BGV_6` actually do.
6. `docs/sharepoint_list_user_guide.md`
   Use this to understand the business meaning of the SharePoint lists
   and document library.
7. `docs/data_mapping_dictionary.md`
   Use this when you need exact field mappings, Forms keys, list fields,
   or flow data paths.

## 2) If you are starting a normal work day

Use these documents in this order:

1. `README.md`
   Run the repo checks and the daily sync command from here.
2. `docs/vscode_ms365_toolchain_guide.md`
   Use the daily Codex-assisted sign-in SOP if you need to re-check auth
   for `pac`, `az`, `m365`, `PnP`, or `Graph`.
3. `docs/collaboration_setup_guide.md`
   Use the daily collaboration loop when exporting, unpacking, editing,
   validating, packing, or importing flows.

Only open the deeper docs when needed:
- `docs/ms365_authentication_runbook.md` for auth problems
- `docs/flows_easy_english.md` for behavior understanding
- `docs/sharepoint_list_user_guide.md` for SharePoint business fields
- `docs/data_mapping_dictionary.md` for exact technical mappings

## 3) If you are doing SharePoint or migration work

Read these:

1. `docs/vscode_ms365_toolchain_guide.md`
2. `docs/ms365_authentication_runbook.md`
3. `docs/collaboration_setup_guide.md`
4. `docs/sharepoint_list_user_guide.md`
5. `docs/data_mapping_dictionary.md`
6. `docs/architecture_flows.md`

Why:
- migration work depends on correct auth, correct tooling, correct list
  understanding, and exact flow/data bindings

## 4) If you are investigating a flow issue

Use these:

1. `docs/flows_easy_english.md`
   Understand the intended business path first.
2. `docs/data_mapping_dictionary.md`
   Check exact fields, Forms keys, and list/library wiring.
3. `docs/sharepoint_list_user_guide.md`
   Check how the SharePoint fields are meant to be used.
4. `docs/architecture_flows.md`
   Check connector and flow integration details.
5. `docs/progress.md`
   Check whether the issue was already investigated or recently changed.

## 5) If you are about to edit or deploy flows

Before editing:
- `README.md`
- `docs/collaboration_setup_guide.md`

Before deployment:
- `README.md`
- `docs/collaboration_setup_guide.md`
- `docs/progress.md`

After deployment:
- `docs/progress.md`
  Log what changed, the validation commands, blockers, and next actions.

## 6) Short version

If someone asks, "What should I read first?" the answer is:

- first-time setup:
  `README.md` -> `docs/vscode_ms365_toolchain_guide.md` ->
  `docs/ms365_authentication_runbook.md` ->
  `docs/collaboration_setup_guide.md`
- daily work:
  `README.md` -> `docs/vscode_ms365_toolchain_guide.md` ->
  `docs/collaboration_setup_guide.md`
- deeper technical lookup:
  `docs/data_mapping_dictionary.md` and
  `docs/sharepoint_list_user_guide.md`

## 7) Best share-out message for collaborators

If you need to send one short message to a collaborator, use this:

`Start with docs/first_time_and_daily_sop_guide.md. It tells you exactly which repo documents to read for first-time setup, daily sign-in, collaboration workflow, SharePoint understanding, and technical mapping lookup.`
