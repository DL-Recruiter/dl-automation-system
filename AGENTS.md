# AGENTS - DL Resources Automation

## Purpose
This file defines mandatory operating rules for AI coding agents working in this repository.

## Hard Constraints
1. Do not commit secrets, tokens, or credentials.
2. Keep `.env` untracked; commit placeholders only in `.env.example`.
3. Do not modify files under `DRAFT/` unless the user explicitly requests it.
4. Preserve cross-file consistency: when contracts, rules, or variables change, update related scripts, tests, and docs together.
5. If any ambiguity exists, ask the user before making assumptions.

## Source-of-Truth Files
- `System_SPEC.md`: system behavior, business rules, contracts, security requirements.
- `AGENTS.md`: repository safety and agent behavior constraints.
- `CODEX_PLAYBOOK.md`: execution workflow for agent sessions.
- `docs/progress.md`: task history, status, blockers, next actions.

## Directory Intent
- `.github/`: CI/CD workflows and repository automation metadata.
- `docs/`: architecture notes, file index, and progress tracking.
- `scripts/active/`: in-progress scripts under active development.
- `scripts/legacy/`: archived/superseded scripts for reference only.
- `flows/`: Power Automate exports and related flow docs (optional).
- `functions/`: serverless entry points (optional).
- `shared/`: reusable logic modules shared across scripts/functions.
- `tests/`: automated test suites and fixtures.
- `out/`: runtime outputs and debug artifacts.
- `DRAFT/`: protected archive area (read-only unless explicitly requested).
- `.venv/`: local Python virtual environment.

## Session Start Protocol
At the start of each session, read:
1. `System_SPEC.md`
2. `AGENTS.md`
3. `CODEX_PLAYBOOK.md`
4. `docs/progress.md`

Then:
1. Summarize current state.
2. Propose a few smallest safe tasks.
3. Execute the smallest task end-to-end.
4. Run focused validation commands.
5. Report changed files, validation results, assumptions, and blockers.

## Change Protocol
1. Perform an impact sweep before edits (`scripts/`, `tests/`, `docs/`, spec/playbook files).
2. Make minimal, targeted changes.
3. Update affected tests/docs in the same task.
4. Log completion and next actions in `docs/progress.md`.
5. If a related file is not changed intentionally, state why in the final report.

## Power Automate Canonical Source (Mandatory)
1. Canonical flow source path: `flows/power-automate/unpacked/Workflows/`.
2. Non-canonical duplicates are read-only unless explicitly requested by the user:
   - `power-automate/`
   - root-level `BGV_*.json` exports (if present later)
3. When editing cloud flows, modify only canonical files and keep formatting stable.
4. After edits, include exact changed flow file paths in the report.

## Collaboration Accounts and Auth Discipline
1. `edwin.teo@dlresources.com.sg` is the development/admin account.
2. `recruitment@dlresources.com.sg` is the operations/collaborator account.
3. Before any PAC CLI command, run `pac auth who` and confirm active identity.
4. If active identity is not intended for the task, stop and switch profile before changes.
5. Do not assume account context from profile name alone; always verify `User` output.

## Power Automate Setup Boundary (CLI-first)
1. Use CLI first for export/unpack/pack/import (`pac solution ...`).
2. UI-only steps must be listed explicitly and minimally:
   - create/sign in connection instances
   - share flows with co-owner permissions
   - bind connection references in designer when required
3. After UI-only steps, return to CLI sync and commit updated artifacts.
