# AGENTS.md

## What this is

JogoCorrida ("racing game") is a **spec-kit / Specify spec-driven development (SDD) project**. There is no application code yet — work happens as a written pipeline: `spec → plan → tasks → implement`. Don't look for build/test/lint commands; there is no toolchain (no package.json, no src/) and none should be invented.

The whole workflow is driven by `/speckit.*` commands (opencode integration, `.` separator), e.g. `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`.

## Golden rule

Each `/speckit.*` command is fully defined in `.opencode/commands/speckit.*.md`. **Read the relevant command file before running it** — that content is authoritative (execution flow, gates, hooks, outputs). `.specify/scripts/bash/*.sh` are the backing helpers; they accept `--json` for machine-readable output (e.g. `.specify/scripts/bash/check-prerequisites.sh --json --paths-only`).

## Standard flow

`/speckit.specify` → `/speckit.clarify` (optional) → `/speckit.plan` → `/speckit.tasks` → `/speckit.implement` → `/speckit.converge`. `/speckit.analyze` is a read-only cross-artifact consistency check that runs after tasks. Most commands enforce prerequisites (e.g. `/speckit.implement` requires plan.md + tasks.md) and stop with instructions if the prior step was skipped.

## Feature artifacts & state

- Each feature lives in `specs/<NNN-short-name>/` (sequential 3-digit prefix — see `feature_numbering` in `.specify/init-options.json`). Created by `/speckit.specify`; contents: `spec.md`, `plan.md`, `tasks.md`, and optionally `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `checklists/`.
- The **active feature** is resolved from `.specify/feature.json` (`feature_directory`), or overridden by env vars `SPECIFY_FEATURE` / `SPECIFY_FEATURE_DIRECTORY`. If feature.json is missing/stale, re-run `/speckit.specify` (or the appropriate step) instead of guessing paths.
- Do not hand-craft these documents for a feature — generate/update them through the commands, which run their own validation gates.

## Spec quality rules (non-negotiable)

The spec is written for **business stakeholders**, not developers:
- No implementation details (no languages, frameworks, APIs, "the API should..."). Focus on WHAT and WHY, not HOW.
- User stories are **prioritized (P1, P2, P3...)** and each must be **independently testable** (each is a viable MVP slice).
- Success criteria must be **measurable and technology-agnostic**.
- At most **3** `[NEEDS CLARIFICATION: ...]` markers; default to reasonable assumptions (recorded in Assumptions) instead of asking.
- Do not embed checklists in the spec. `/speckit.specify` writes a spec-quality checklist to `specs/<feature>/checklists/requirements.md`; `/speckit.clarify` re-validates it.

## Constitution

`.specify/memory/constitution.md` is currently an **unfilled template** (all `[PLACEHOLDER]` tokens). It should be filled in via `/speckit.constitution` before meaningful work. While it remains a template, `/speckit.analyze` and `/speckit.converge` skip constitution checks gracefully — so don't treat placeholders as real constraints.

## tasks.md format

Tasks are grouped by user story (one phase per story, priority order) and use a strict checklist line format:

```
- [ ] T001 Create project structure per implementation plan
- [ ] T012 [P] [US1] Create User model in src/models/user.py
```

- `[P]` = parallelizable (different files, no deps); `[US#]` = user-story phase task.
- **Tests are OPTIONAL** — only add test tasks if the spec explicitly requests them or TDD was chosen.
- `/speckit.implement` marks completed tasks `[X]` in place.

## Git

- Branches: `main` and `dev` (currently checked out). Feature work is expected on `<NNN>-short-name` branches (created via the git extension hook during `/speckit.specify`).
- Remote is GitHub (`https://github.com/jpombo/JogoCorrida.git`). `/speckit.taskstoissues` converts tasks to GitHub issues but **requires the GitHub MCP server** and refuses non-GitHub remotes.

## Premissas do Projeto

- **Idioma**: Todo o projeto e documentação devem utilizar Português do Brasil.
- **Comunicação**: Todas as interações, comentários, mensagens e respostas devem ser feitas exclusivamente em Português do Brasil.
- **Informação Insuficiente**: Em caso de dúvida ou informação insuficiente, sempre pergunte ao usuário antes de prosseguir. Não assuma nada sem consultar previamente.