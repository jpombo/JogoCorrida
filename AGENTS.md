# AGENTS.md

## What this is

JogoCorrida ("racing game") is a **spec-kit / Specify spec-driven development (SDD) project** built on **Godot 4.7.2** (GDScript). Features are developed through the written pipeline `spec → plan → tasks → implement`, and the resulting GDScript code lives in `src/`. The whole workflow is driven by `/speckit.*` commands (opencode integration, `.` separator), e.g. `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`.

## Estado atual

Specs **concluídas e commitadas** na branch `dev`: **SPEC-001** (controle do veículo), **SPEC-002** (estrada e scrolling), **SPEC-003** (ambientes), **SPEC-004** (trânsito e decoração), **SPEC-005** (colisão e drift), **SPEC-006** (colisão NPC↔NPC — `b52a900`, com pendência só de FR-046 abaixo), **SPEC-007** (combustível — `ab1c3b9`), **SPEC-008** (progressão, estados, combustível e galões) e **SPEC-009** (dificuldade e balanceamento) — SPEC-009 implementada, convergida, aceite manual concluído (T028) e commitada nesta entrega.

- **Aceite manual das SPEC-006/008/009 (2026-10-16)**: usuário executou os quickstarts e **não identificou problemas** — SPEC-006: Validação 2.9 (Gelo + 5 NPCs + transição + colisão NPC×NPC junto ao jogador), Validação 3 (configurabilidade) e endurance de 3×10 min (T037/T050/T051/T052 → `[X]`, `tasks.md` Phase 13); SPEC-008: passos manuais 1–12 + calibração §4 sem ajuste de valores (T053/T055 → `[X]`, `tasks.md` Phase 16); SPEC-009: quickstart §3.1–§3.5 com calibração §5 não acionada (T028 → `[X]`, `tasks.md` Phase 11). **Documentos propagados junto**: quickstart da SPEC-008 (passos 1, 5, 6 e 11) e contratos `ui_commands.md` §1 e `game_state_transitions.md` §1 ajustados para os fluxos de fim da SPEC-009 (FR-020/FR-021 substituem o "Tentar novamente" do FR-034 — vitória com "Continuar próxima fase"/"Voltar ao menu", fim de jogo só "Voltar ao menu"; menu com 3 linhas). Suíte completa na mesma data: **63 suítes, 388 casos, exit 101**.

- **Ajustes pós-implementação da SPEC-009 (2026-10-14, T037/T038 — Phase 10)**: (1) **correção do ESC na corrida** — o menu de pausa (com a opção "Voltar ao menu") não aparecia: o mesmo `ui_cancel` que pausou continua "just pressed" no quadro da virada PLAYING→PAUSED e a UI retomava no mesmo quadro (o painel ligava e desligava sem nunca ser desenhado); guarda de quadro nos dois lados — `_frame_pausa` em `ui_manager.gd` (`_aplicar_estado`/`_process_pausa`) e `_frame_play` em `gameplay_manager.gd` (`_show_playing`/`_processar_playing`) —, independente da ordem de processamento entre os nós, com suíte nova `tests/unit/pause_esc_test.gd` (3 casos; verificada como RED com as guardas removidas); (2) **valores de modo recalibrados** (clarify 2026-10-14, registrado em `spec.md` `## Clarifications` + adendo no Input): Normal 2,0× → **3,0×** e Desafio 3,0× → **4,0×** (quádruplo da base) — só em `velocidade` (`game_config.gd`), Relaxante e os demais 4 fatores por modo inalterados; texto propagado em spec/plan/quickstart/research/data-model/tasks e suítes `difficulty_manager`/`environment_matrix`/`state_flow`/`speed`/`stability` (cenário máximo agora 4,0×). T028 concluído em 2026-10-16 (Phase 11 — sem problemas, calibração §5 não acionada). Suíte completa **63 suítes, 388 casos, exit 101** (2 execuções consecutivas).

- **SPEC-009 — onde está (2026-10-13)**: código em `src/difficulty/difficulty_manager.gd` (modo vigente + 5 fatores + fator de ciclo), `src/game/race_progression.gd` (sequência `% 4`, ciclos, bônus 0,2%/ciclo), extensões em `vehicle_controller.gd`/`traffic_vehicle.gd`/`traffic_manager.gd` (velocidade × fator, densidade com clamp absoluto), `fuel_system.gd` (consumo por km constante + penalidade × fator), `fuel_can_manager.gd` (taxa × `frequencia_galoes`, intervalo × `distancia_galoes`), `ui_manager.gd` (menu 3 linhas com linha "Modo" — `select_next_mode`/`atualizar_modo`; vitória 2 opções com `continue_next_phase`, fim de jogo só "Voltar ao menu") e orquestração em `gameplay_manager.gd` (`dificuldade`/`progresso` como fields — testes sintéticos intactos (R12); `_aplicar_fatores_por_corrida()` no `_ready`/largada/continuar/reinício; `registra_vitoria`/`zerar_ciclo_por_derrota` nos mesmos pontos de transição; `_preparar_proxima_corrida` = ambiente % 4 + fator de ciclo + reset + injeção). `tasks.md`: **T001–T038 `[X]`** (inclui **Phase 8: Convergence** — T029–T033, resposta aos 5 achados da 1ª rodada do `/speckit.converge`: pipeline canônico com colisões no cenário máximo + NPC×NPC a 3×/4× + injeção/pista/tanque reais na estabilidade, corrida de referência nas 12 combinações, menu de 3 linhas testado, nascimentos contínuos e tabela §4 do quickstart; e **Phase 9: Convergence** — T034–T036, resposta aos 3 achados LOW da 2ª rodada: composição do seletor no orquestrador testada, citação de "Critérios 12.1–12.5" corrigida no plan.md e referência de fase inexistente corrigida no T028) — **T028 (aceite manual do quickstart §3.1–§3.5 + calibração §5) concluído em 2026-10-16** (Phase 11: sem problemas identificados, calibração §5 não acionada). 12 suítes novas (`difficulty_manager`, `difficulty_speed`, `difficulty_fuel`, `difficulty_traffic_can`, `difficulty_environment_matrix`, `difficulty_stability`, `difficulty_state_flow`, `difficulty_combo_reference`, `difficulty_menu_selector`, `difficulty_menu_flow`, `cycle_progression`, `cycle_flow` — 61 casos). Suíte completa: **63 suítes, 389 casos, exit 101** (2 execuções consecutivas verdes; +1 caso SC-016 na remediação do `/speckit.analyze`). — as 50 legadas verdes **sem qualquer ajuste** (garantia R12). Pendência de fluxo: nenhuma — T028 concluído (2026-10-16) e SPEC-009 commitada nesta entrega.

- **SPEC-008 — onde está (2026-10-11)**: código em `src/track/` (TrackManager/TrackMarkers), `src/items/` (FuelCan/FuelCanManager), `src/ui/ui_manager.gd` (menu/pausa/vitória/game over/indicador de distância), extensões do `fuel_system.gd` (capacidade derivada + `restaurar`), resets em Road/Traffic/Collision/NpcCollision/Decoration/Player e orquestração em `gameplay_manager.gd` (`_reset_corrida`: preparação menu→READY e virada READY→PLAYING); camadas `TrackLayer`/`ItemsLayer`/`UiLayer` em `gameplay.tscn`; bloco `track_*`/`fuel_can_*`/rótulos `ui_*` em `game_config.gd`; asset `assets/decoracao/gasolina.png`. `tasks.md`: T001–T052, T054, T056–T061 `[X]` — **T053/T055 (aceite manual do quickstart e calibração) concluídos em 2026-10-16** (Phase 16 — sem problemas, nenhum valor de calibração ajustado). 9 suítes novas (`track_*`, `fuel_can_*`, `fuel_sizing`, `fuel_game_over_flow`, `ui_screens`, `race_reset`, `game_config_008`). Suíte completa: **50 suítes, 324 casos, exit 101**.

- **Ajustes pós-implementação da SPEC-008 (2026-10-11, T057/T058 — Phase 13)**: (1) menu com destaque da opção ativa — retângulo semitransparente atrás de "Selecionar veículo"+nome ou "Iniciar corrida", navegação `ui_up`/`ui_down`, `ui_accept` só inicia com "Iniciar corrida" destacada; (2) banda `INÍCIO`/`CHEGADA` criada na entrada em `READY` (`_show_ready`) — antes só nascia após o timer de 1 s na virada READY→PLAYING, causando a percepção de demora. Registrados em `tasks.md` Phase 13, `contracts/ui_commands.md` §3 e `contracts/game_state_transitions.md` §3; quickstart passos 1–2 atualizados. Validados pelo usuário sem problemas; suíte completa **50/324, exit 101**.

- **Ajustes pós-implementação da SPEC-008 (2026-10-12, T059/T060 — Phase 14 + T061 — Phase 15, converge)**: (1) `_on_start_race` prepara a corrida antes do `start_game` — `_reset_corrida()` na entrada menu→READY: indicador `0,0 km / total` e tanque na carga inicial **já no READY** (antes só na virada READY→PLAYING, o READY exibia estado residual); (2) `_show_menu` congela o processamento do jogador (`set_process(false)`) — nada processa input em segundo plano no MENU, religando em `_show_playing` (consistente com o caminho pós-vitória/game over); (3) documentação dos pontos de chamada do reset sincronizada (docstring de `_reset_corrida`, comentário de `_on_state_changed`, `contracts/game_state_transitions.md` §3 — inclui que `go_to_menu` não chama o reset completo). T053/T055 concluídos em 2026-10-16 (Phase 16 — aceite manual/calibração sem problemas). Suíte completa **50/324, exit 101**.

- **SPEC-007 — onde está (2026-10-10)**: código em `src/fuel/fuel_system.gd` + `src/ui/fuel_hud.gd`, wiring em `gameplay_manager.gd` e camada `FuelHudLayer` em `gameplay.tscn`, bloco `fuel_*`/`collision_fuel_penalty` em `game_config.gd`; 6 suítes `fuel_*_test.gd` (43 casos — testes obrigatórios 1–27 do texto-fonte). `tasks.md`: **T001–T022 todos `[X]`** — T020 (aceite manual, 10 passos do quickstart) validado em 2026-10-10 sem ajustes de calibração/visual. Suíte completa: **41 suítes, 259 casos, exit 101**. Commit `ab1c3b9` (inclui a constituição v3.0.0 e o ajuste de assets/hitboxes); pendência de fluxo: só `/speckit.converge`.

- **Ajuste de assets e recalibração de hitboxes (2026-10-10)**: conteúdo dos 14 PNGs de NPC (canvas 32×64; caminhão 32×128 inalterado — contrato da SPEC-004 preservado) e dos 2 sprites do jogador normalizado com margens; sprites de drift do jogador removidos (zero referências em código/specs/docs); `carro_01png` → `carro_01.png`; `*.import` regenerados. Hitboxes recalibradas ao bbox visível em `game_config.gd` (jogador 22×44; passeio/utilitário 22×38; esporte 22×46; caminhão 30×64) + 3 testes com constantes antigas corrigidos (`collision_cooldown_test.gd` realinhamento pós-drift; `npc_collision_bounds_test.gd` limites do esporte derivados do config). **Carro-prata verificado**: sonda de 4000 nascimentos com semântica do pool (cache FR-017) → sorteio uniforme (12,1% ≈ 1/7 dos utilitários, ~3,5% de todos os veículos — taxa baixa por design); presença confirmada no aceite manual (~10 min). Registro: Phase 14 das SPEC-004 e SPEC-005; suíte completa **41/259, exit 101**.

- **SPEC-006 — onde está (2026-10-09)**: código em `src/collision/npc_*.gd`, integração em `gameplay_manager.gd`, 9 suítes `npc_*` em `tests/unit/`; `tasks.md` com T001–T054 **todos `[X]`** — inclui o aceite manual **T037, T050, T051, T052** (concluído em 2026-10-16, Phase 13 — sem problemas; só o FR-046 abaixo segue pendente). Suíte completa: **35 suítes, 214 casos, exit 101**.
- **Clarify da SPEC-006 (2026-10-09, "trânsito real")**: causa-raiz dos relatos DESERT/FOREST confirmada pela sonda `tests/unit/test_traffic_corridor_probe.gd` (**só-reporta**: A=266 quadros de arranjo fechante, B=71 de grude do limitador, D=0 contatos → US1 inatingível com o limitador atual). A spec recebeu **FR-046** (o espaçamento mínimo do SPEC-004 cede, durante o movimento, entre velocidades diferentes na mesma trajetória até o contato; nascimento e pares de mesma velocidade inalterados), o **6º cenário de aceitação da US1** (caso natural resolve em contato+drift) e a premissa de corredores reescrita com **dívida conhecida da SPEC-004** (recuo de faixa para faixa alheia; convergência no estreitamento sem rechecagem de ordenação). **FR-046 ainda não foi implementado** — `plan.md`/`tasks.md` estão defasados em relação ao amend.
- **Pendências da SPEC-006**: só o fluxo do FR-046 — `/speckit.analyze` (consistência spec↔plan↔tasks após o clarify) → atualizar plan/tasks para o FR-046 → implementar a cedência do limitador → reativar os asserts da sonda (A/B/D). O aceite manual (T037/T050–T052) foi concluído em 2026-10-16 sem problemas (Phase 13).
- **Git**: SPEC-006 (specs, `src/collision/npc_*.gd`, suítes `npc_*`, sonda e correção de textura) commitada em `b52a900`; SPEC-007 + constituição v3.0.0 + ajuste de assets/hitboxes/docs commitados em `ab1c3b9`.
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