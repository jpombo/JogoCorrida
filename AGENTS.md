# AGENTS.md

## What this is

JogoCorrida ("racing game") is a **spec-kit / Specify spec-driven development (SDD) project** built on **Godot 4.7.2** (GDScript). Features are developed through the written pipeline `spec → plan → tasks → implement`, and the resulting GDScript code lives in `src/`. The whole workflow is driven by `/speckit.*` commands (opencode integration, `.` separator), e.g. `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`.

## Estado atual

Specs **concluídas e commitadas**: **SPEC-001** (controle do veículo), **SPEC-002** (estrada e scrolling), **SPEC-003** (ambientes), **SPEC-004** (trânsito e decoração), **SPEC-005** (colisão e drift). **SPEC-006** (colisão NPC↔NPC) e **SPEC-007** (combustível) estão **implementadas e com suíte verde, porém não commitadas** (trabalho pendente na branch `dev`).

- **SPEC-007 — onde está (2026-10-10)**: código em `src/fuel/fuel_system.gd` + `src/ui/fuel_hud.gd`, wiring em `gameplay_manager.gd` e camada `FuelHudLayer` em `gameplay.tscn`, bloco `fuel_*`/`collision_fuel_penalty` em `game_config.gd`; 6 suítes `fuel_*_test.gd` (43 casos — testes obrigatórios 1–27 do texto-fonte). `tasks.md`: T001–T019 e T021–T022 `[X]` — **falta só o aceite manual T020** (10 passos do quickstart no editor). Suíte completa: **41 suítes, 259 casos, exit 101**. Pendência do fluxo: `/speckit.analyze`/`/speckit.converge` + commit.

- **Ajuste de assets e recalibração de hitboxes (2026-10-10)**: conteúdo dos 14 PNGs de NPC (canvas 32×64; caminhão 32×128 inalterado — contrato da SPEC-004 preservado) e dos 2 sprites do jogador normalizado com margens; sprites de drift do jogador removidos (zero referências em código/specs/docs); `carro_01png` → `carro_01.png`; `*.import` regenerados. Hitboxes recalibradas ao bbox visível em `game_config.gd` (jogador 22×44; passeio/utilitário 22×38; esporte 22×46; caminhão 30×64) + 3 testes com constantes antigas corrigidos (`collision_cooldown_test.gd` realinhamento pós-drift; `npc_collision_bounds_test.gd` limites do esporte derivados do config). **Carro-prata verificado**: sonda de 4000 nascimentos com semântica do pool (cache FR-017) → sorteio uniforme (12,1% ≈ 1/7 dos utilitários, ~3,5% de todos os veículos — taxa baixa por design); presença confirmada no aceite manual (~10 min). Registro: Phase 14 das SPEC-004 e SPEC-005; suíte completa **41/259, exit 101**.

- **SPEC-006 — onde está (2026-10-09)**: código em `src/collision/npc_*.gd`, integração em `gameplay_manager.gd`, 9 suítes `npc_*` em `tests/unit/`; `tasks.md` com T001–T049 e T053 `[X]` — faltam só aceite manual **T037, T050, T051, T052** (T054 = esta atualização). Suíte completa: **35 suítes, 214 casos, exit 101**.
- **Clarify da SPEC-006 (2026-10-09, "trânsito real")**: causa-raiz dos relatos DESERT/FOREST confirmada pela sonda `tests/unit/test_traffic_corridor_probe.gd` (**só-reporta**: A=266 quadros de arranjo fechante, B=71 de grude do limitador, D=0 contatos → US1 inatingível com o limitador atual). A spec recebeu **FR-046** (o espaçamento mínimo do SPEC-004 cede, durante o movimento, entre velocidades diferentes na mesma trajetória até o contato; nascimento e pares de mesma velocidade inalterados), o **6º cenário de aceitação da US1** (caso natural resolve em contato+drift) e a premissa de corredores reescrita com **dívida conhecida da SPEC-004** (recuo de faixa para faixa alheia; convergência no estreitamento sem rechecagem de ordenação). **FR-046 ainda não foi implementado** — `plan.md`/`tasks.md` estão defasados em relação ao amend.
- **Pendências da SPEC-006**: `/speckit.analyze` (consistência spec↔plan↔tasks após o clarify) → atualizar plan/tasks para o FR-046 → implementar a cedência do limitador → reativar os asserts da sonda (A/B/D) → aceite manual T037/T050–T052 → commit.
- **Git**: todo o trabalho da SPEC-006 (`specs/006-...`, `src/collision/npc_*.gd`, suítes `npc_*` e a sonda) mais a correção de textura de NPCs (`test_traffic_texture_category.gd`, `traffic_vehicle.gd`) está **uncommitted** em `dev`.
- A SPEC-005 passou por **6 ajustes pós-implementação** (aceite manual, 2026-10-05): ajustes 1–3 e 5 de domínio do trânsito (registrados no spec da SPEC-004: separação no nascimento, corredor lateral, densidade mínima, faixas por velocidade) e ajustes 4 e 6 da SPEC-005 (bloqueio da aceleração pós-colisão — FR-036/SC-013; retorno do NPC à faixa após a ultrapassagem — FR-019/FR-021/SC-014). Todos validados na suíte completa; registro em `tasks.md` Phase 13 de cada spec.
- 2026-10-05: corrigidos dois testes instáveis (flaky) causados por **reciclagem do pool no mesmo quadro** (mesma instância desativada e reativada entre medições): guarda de salto no eixo Y em `test_traffic_speed_ordering.gd` e invalidação de baseline pelo sinal `element_recycled` em `test_decoration_manager.gd`. Suíte completa verde em 12 execuções consecutivas.

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