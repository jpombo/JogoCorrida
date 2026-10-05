# AGENTS.md

## What this is

JogoCorrida ("racing game") is a **spec-kit / Specify spec-driven development (SDD) project** built on **Godot 4.7.2** (GDScript). Features are developed through the written pipeline `spec → plan → tasks → implement`, and the resulting GDScript code lives in `src/`. The whole workflow is driven by `/speckit.*` commands (opencode integration, `.` separator), e.g. `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`.

## Estado atual

Specs concluídas e implementadas: **SPEC-001** (controle do veículo), **SPEC-002** (estrada e scrolling), **SPEC-003** (ambientes), **SPEC-004** (trânsito e decoração), **SPEC-005** (colisão e drift) — 24 suítes de teste, 160 casos verdes (exit 101).

- A SPEC-005 passou por **6 ajustes pós-implementação** (aceite manual, 2026-10-05): ajustes 1–3 e 5 de domínio do trânsito (registrados no spec da SPEC-004: separação no nascimento, corredor lateral, densidade mínima, faixas por velocidade) e ajustes 4 e 6 da SPEC-005 (bloqueio da aceleração pós-colisão — FR-036/SC-013; retorno do NPC à faixa após a ultrapassagem — FR-019/FR-021/SC-014). Todos validados na suíte completa; registro em `tasks.md` Phase 13 de cada spec.
- 2026-10-05: corrigidos dois testes instáveis (flaky) causados por **reciclagem do pool no mesmo quadro** (mesma instância desativada e reativada entre medições): guarda de salto no eixo Y em `test_traffic_speed_ordering.gd` e invalidação de baseline pelo sinal `element_recycled` em `test_decoration_manager.gd`. Suíte completa verde em 12 execuções consecutivas.
- **Próxima feature planejada**: colisão NPC↔NPC (o NPC de baixo muda de pista), a iniciar com `/speckit.specify` após confirmação do usuário.

## Build & test

- Engine: `Godot_v4.7.2-stable_linux.x86_64` (binário em `~/Downloads/_installers/`); a cena principal é `res://src/game/gameplay.tscn`.
- Testes: GdUnit4 em `tests/unit/`. Rodar a suíte completa (o runner sai com **exit 101** quando está tudo verde):
  `GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit`
- `*.import` é ignorado pelo git: abra o editor Godot uma vez por máquina antes dos testes headless, para gerar os imports dos assets.
- `tools/resize_decoration_assets.py` é um **validador somente leitura** dos assets de decoração (nomes, alturas da SC-027, proporção, pesos somando 100) — nunca escreve arquivos.

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

`.specify/memory/constitution.md` is **filled in** (v2.0.0) and is **non-negotiable**. Violations of its MUST principles are CRITICAL findings in `/speckit.analyze` and must be resolved by amending the constitution via `/speckit.constitution` or by changing the spec/plan/tasks — never by reinterpreting the principle. Note: the constitution itself is written in English, which contradicts its own §VI (documentation in pt-BR); flag this if a spec touches it.

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