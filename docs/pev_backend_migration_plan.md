# PEV Backend Migration Plan

This document is the cutover plan for migrating the current `BGV` technical backend to `PEV` without breaking live flows.

## Goal

Move from the current `BGV` technical naming to `PEV` across:

- SharePoint list display names
- document-library display names
- dashboard workbook names
- flow display names
- deployment settings / environment variable aliases
- user-facing templates and generated file names

while keeping live production working throughout the migration.

## Important Constraint

The current production system still depends on live technical objects such as:

- `BGV_Candidates`
- `BGV_Requests`
- `BGV_FormData`
- `BGV Records`
- `BGV_*` flow display names
- `BGV-...` / `REQ-BGV-...` identifiers

A direct one-pass rename would break:

- SharePoint list bindings
- folder-path logic
- Microsoft Forms prefill logic
- dashboard refresh joins
- PAC deployment token replacement
- existing historical RequestID / CandidateID references

So this migration must be done as a staged cutover.

## Recommended Cutover Stages

### Stage 1. Safe wording and alias layer

Completed / in progress:

- user-facing `BGV` wording replaced with `PEV`
- deployment-settings builder now accepts both `BGV_*` and `PEV_*` environment variables
- `scripts/active/pev_build_deployment_settings.ps1` added as a migration-friendly wrapper

This stage does not change live SharePoint object names.

### Stage 2. Parallel PEV technical objects

Create the new live technical objects in parallel:

- `PEV_Candidates`
- `PEV_Requests`
- `PEV_FormData`
- `PEV Records`

Then copy schema and existing data across from the current `BGV` stores.

### Stage 3. Parallel PEV materialized flow package

Build a parallel deployable solution that points to:

- `PEV_*` list IDs
- `PEV Records` library ID
- new dashboard workbook/file names
- updated visible flow display names

At this stage, old `BGV_*` production flows stay on until the `PEV_*` package is fully validated.

### Stage 4. Controlled validation

Test all critical tracks in the PEV-connected package:

- candidate declaration
- authorization signature detection
- employer send
- employer response
- report summary generation
- reminders and escalations
- dashboard refresh

### Stage 5. Production cutover

Only after successful parallel validation:

- stop old `BGV_*` production flows
- start the `PEV_*` production package
- monitor live runs

### Stage 6. Legacy retirement

After stable operation:

- archive or retire old `BGV_*` flows
- keep old `BGV-...` and `REQ-BGV-...` IDs for historical records unless there is a separate approved data-ID migration

## What Should Not Be Renamed Blindly

Do not mass-replace these in live production without parallel validation:

- SharePoint list internal identities
- request and candidate ID prefixes
- file/folder paths used by active flows
- flow GUID-linked references
- Teams group/channel IDs
- Form IDs
- template file IDs

## Current Recommendation

Proceed with:

1. alias-layer support in scripts and deployment settings
2. creation of parallel `PEV_*` stores
3. parallel materialized flow package
4. end-to-end validation
5. cutover

Do not do an in-place mass rename of the current production backend.
