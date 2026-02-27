# CODEX_PLAYBOOK - Codex Agent Playbook Template

## 1) Purpose
This playbook standardizes how coding agents work in the **DL Resources Automation** repository: read context, scope changes, edit minimally, validate, and report clearly.

## 2) Source of Truth
- `System_SPEC.md`: authoritative source for API contracts, business rules, security constraints, and deployment expectations.
- `CODEX_PLAYBOOK.md`: authoritative source for agent workflow behavior.
- `AGENTS.md`: hard repository safety constraints.

If there is any conflict or ambiguity, ask the user before proceeding.

## 3) Repo Safety Rules
- Never commit secrets or tokens.
- Keep `.env` out of version control; use `.env.example` placeholders.
- Do not modify `DRAFT/` unless explicitly asked.
- Preserve unrelated user edits.
- Treat `out/` as runtime output; do not rely on generated artifacts as source of truth.

## 4) Folder Intent
- `scripts/active/`: active scripts under development.
- `scripts/legacy/`: superseded scripts kept for historical reference.
- `functions/`: serverless trigger/entrypoint code.
- `shared/`: reusable non-trigger logic.
- `flows/`: exported Power Automate artifacts.
- `docs/`: documentation and progress history.
- `tests/`: automated tests.
- `out/`: generated runtime/debug output.
- `.github/`: CI/CD workflows and metadata.

## 5) Working Protocol for Codex
Before substantial edits:
1. Context loading: read `System_SPEC.md`, `AGENTS.md`, `CODEX_PLAYBOOK.md`, and `docs/progress.md`.
2. Scope scan: inspect related scripts, tests, and docs.
3. Feasibility check: verify imports/dependencies/config assumptions.
4. Plan: state intended minimal edits.
5. Confirm: ask user questions if ambiguity remains.

During edits:
1. Keep changes minimal and targeted.
2. Maintain naming and structure consistency.
3. Perform impact sweep and update all affected files.
4. Avoid broad refactors unless requested.

After edits:
1. Run focused validation commands.
2. Report changed files and key outcomes.
3. Report files reviewed but intentionally unchanged (with reason), when relevant.

## 6) Validation Protocol
Use the smallest relevant checks for the change:
- `pytest`
- `ruff check .`
- `mypy ...`
- `eslint ...`
- `tsc ...`

If validation cannot be executed, state exactly why.

## 7) Change Boundaries
- Do not move/rename large parts of the repository without clear need.
- Prefer low-risk, traceable iterations.
- Keep behavior/documentation changes aligned in the same task.

## 8) Acceptance Mindset
Prefer reliability, determinism, and auditability over large speculative rewrites.

## 9) Default Session Loop
For each session:
1. Read `AGENTS.md`, `System_SPEC.md`, `CODEX_PLAYBOOK.md`, `docs/progress.md`.
2. Summarize current status.
3. Propose three small safe tasks.
4. Execute the smallest task end-to-end.
5. Report changes, commands run, results, assumptions, and blockers.

## 10) Patch Protocol (Mandatory)
When changing any module:
1. Reiterate user intent if needed.
2. Run feasibility checks for new areas.
3. Do impact sweep for related imports/call sites/docs/tests.
4. Update affected scripts/tests/docs/spec together.
5. Include reproducible validation commands.
6. Provide explicit changed file list in the report.
