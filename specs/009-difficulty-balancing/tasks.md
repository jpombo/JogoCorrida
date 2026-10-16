# Tasks: SPEC-009 — Dificuldade e Balanceamento

**Input**: Design documents from `/specs/009-difficulty-balancing/`

**Prerequisites**: plan.md, spec.md (4 US), research.md (R1–R13), data-model.md, contracts/ (difficulty_manager_api, environment_cycle, ui_commands), quickstart.md

**Tests**: **Incluídos** — a spec pede explicitamente "Testes de balanceamento e regressão" (§2.1) e 9 suítes novas `difficulty_*`/`cycle_*` no plan (R12 exige regressão verde das 50 suítes legadas sem ajuste).

**Organization**: tarefas agrupadas por user story; cada fase é um incremento testável independente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizável (arquivos diferentes, sem dependências)
- **[Story]**: US1–US4 conforme spec.md
- Caminhos exatos: `src/` (monogodot, raiz do repo), `tests/unit/` GdUnit4

## Path Conventions

- Engine: Godot 4.7.2, cena principal `src/game/gameplay.tscn`
- Componentes novos: `RefCounted` instanciados pelo `GameplayManager` (padrão TrackManager/FuelSystem)
- Zero valores mágicos: tudo no bloco config (T001); fallbacks 1,0 para fatores ausentes

---

## Phase 1: Setup (infraestrutura compartilhada)

**Purpose**: bloco de configuração único que alimenta todos os sistemas (T001 é pré-requisito de tudo)

- [X] T001 [P] Criar bloco `## Dificuldade e Progressão (SPEC-009)` em src/config/game_config.gd: `difficulty_modes` (relaxing/normal/challenge × 5 fatores), `difficulty_default_mode = "normal"`, `difficulty_cycle_bonus_increment = 0.002`, `environment_sequence = ["PLAINS","DESERT","FOREST","ICE"]` + chaves `ui_strings` novas (`mode_label`, `mode_relaxing`, `mode_normal`, `mode_challenge`, `continue_next_phase`) — valores de calibração conforme data-model.md §2 e research R13, com comentários de ajuste por US

**Checkpoint**: config completo — nenhum sistema lê nada ainda

---

## Phase 2: Foundational (pré-requisito bloqueante)

**Purpose**: `DifficultyManager` — dono do modo vigente; TODAS as user stories dependem dele

**⚠️ CRITICAL**: nenhuma US pode começar antes desta fase

- [X] T002 Implementar src/difficulty/difficulty_manager.gd (RefCounted): `definir_modo` (inválido → default "normal"), `ciclar_modo`, `get_modo`, `aplicar_fator_ciclo`, `fator_ciclo`, getters dos 5 fatores, `fator_velocidade_total`, `efetiva(base)` — semântica exata de contracts/difficulty_manager_api.md §1, fallback 1,0 por campo ausente (R8/R12)
- [X] T003 [P] Criar tests/unit/difficulty_manager_test.gd (GdUnit4): modos e ordem do ciclo, fatores de cada modo, fallback Normal para modo inválido, fator de ciclo composto — invariantes de data-model.md §2 (SC-012)

**Checkpoint**: DifficultyManager pronto e testado — as 4 US podem avançar em paralelo

---

## Phase 3: User Story 1 - Escolher o modo e correr na velocidade do modo (Priority: P1) 🎯 MVP

**Goal**: três modos aplicam 1×/3×/4× à velocidade de jogador e NPCs (bases nunca mutadas, sem acúmulo); o menu ganha a linha "Modo" (placeholder da SPEC-013); Normal é o padrão.

**Independent Test**: quickstart §3.1–§3.2 — selecionar cada modo no menu e sentir/medi 1×/3×/4×; suíte `difficulty_speed_test` + `difficulty_fuel_test` (consumo) verdes; sem regressão em Relaxante.

### Tests for User Story 1

- [X] T004 [P] [US1] Criar tests/unit/difficulty_speed_test.gd: 1×/3×/4× do jogador (teto/aceleração/frenagem/desaceleração natural, razões preservadas), 1×/3×/4× dos 4 tipos de NPC (bases 90/90/100/120 nunca mutadas), 5 reinícios sem acúmulo, curva de aceleração normalizada pelo teto efetivo, timers de largada/pausa inalterados (SC-001–003); distância: total da pista idêntica nos 3 modos, percorrida nunca acima do total, 0 acréscimos por temporizadores (SC-004); colisão: em fator 3 e 4, contato registrado no mesmo encontro — 0 atravessamentos — e penalidade aplicada uma única vez, com o CollisionSystem no padrão das suítes `npc_collision_*` (SC-009/FR-014; contingência de substepping do research R4 fica documentada, não implementada)
- [X] T005 [P] [US1] Criar tests/unit/difficulty_fuel_test.gd (parte consumo): consumo por km constante entre os 3 modos (Relaxante/Normal/Desafio com a mesma distância), sem aplicação dupla do fator, regressão 1× idêntica ao comportamento atual (SC-008)

### Implementation for User Story 1

- [X] T006 [P] [US1] Estender src/player/vehicle_controller.gd: campo `fator_dificuldade` (default 1.0); escalar velocidade máxima/aceleração/frenagem/desaceleração natural pelo fator mantendo as razões; normalizar `get_vertical_position()` pelo teto efetivo (R1/R2, contracts/difficulty_manager_api.md §4)
- [X] T007 [P] [US1] Estender src/traffic/traffic_vehicle.gd: campo `fator_dificuldade` (default 1.0); `get_speed()` = velocidade da categoria × fator (R1; bases intactas — SPEC-004 FR-017)
- [X] T008 [US1] Estender src/traffic/traffic_manager.gd: campos `dificuldade` (ref) e `fator_dificuldade` (fallback 1.0); semear o fator vigente no `activate()`/_nascer() de cada NPC (R11)
- [X] T009 [US1] Estender src/fuel/fuel_system.gd: campo `fator_velocidade` (default 1.0); `_taxa_consumo` normaliza pelo teto efetivo do jogador e multiplica a taxa — consumo por km independente do modo (R3)
- [X] T010 [US1] Estender src/ui/ui_manager.gd: 3ª linha de menu "Modo" (navegação `wrapi(0,3)`, destaque semitransparente existente, rótulo via `ui_strings`), sinal `select_next_mode`, método `atualizar_modo(rotulo)` (contracts/ui_commands.md §1–§2, R10)
- [X] T011 [US1] Estender src/game/gameplay_manager.gd: instanciar DifficultyManager no `_ready` (o RaceProgression é da US2 — T015); injeção por referência em traffic_layer, items_layer, fuel_system, ui_root e fatores de velocidade no controller; `definir_modo("normal")` no arranque; handler `_on_select_next_mode` (ciclar + atualizar rótulo); refresh do fator de velocidade/consumo em `_on_start_race` (contracts/difficulty_manager_api.md §2–§3)

**Checkpoint**: US1 funcional — modo selecionável, velocidade do modo aplicada, consumo coerente

---

## Phase 4: User Story 2 - Avançar por ciclos infinitos de ambientes com dificuldade crescente (Priority: P2)

**Goal**: sequência PLAINS→DESERT→FOREST→ICE cicla com bônus 0,2% por ciclo; vitória oferece "Continuar próxima fase"/"Voltar ao menu"; derrota zera o ciclo e só tem "Voltar ao menu"; bônus preservado por sessão.

**Independent Test**: quickstart §3.4 — vencer 4 fases seguidas (avanço + bônus), derrota e recomeço em PLAINS com ciclos preservados; suítes `cycle_progression_test` + `cycle_flow_test` verdes.

### Tests for User Story 2

- [X] T012 [P] [US2] Criar tests/unit/cycle_progression_test.gd: sequência `environment_sequence % 4` (gelo → planície), `registra_vitoria` (4 vitórias → ciclo+1 e posição 0), `zerar_ciclo_por_derrota` (pos=0, vitorias=0, ciclos preservados), `fator_ciclo = 1 + 0.002 × ciclos` (SC-015–017)

### Implementation for User Story 2

- [X] T013 [P] [US2] Criar src/game/race_progression.gd (RefCounted): estado `posicao`/`vitorias_ciclo`/`ciclos_concluidos` (sessão apenas — FR-023), `ambiente_atual()`, `registra_vitoria()`, `zerar_ciclo_por_derrota()`, `fator_ciclo()` — data-model.md §4, contracts/environment_cycle.md §1–§2
- [X] T014 [US2] Estender src/ui/ui_manager.gd: painel de vitória → opções ["Continuar próxima fase", "Voltar ao menu"] + sinal `continue_next_phase`; painel de fim de jogo → apenas ["Voltar ao menu"]; `_process_fim(state)` por painel (vitória vs game over); remover "Tentar novamente" das telas de fim (FR-020/021, contracts/ui_commands.md §4)
- [X] T015 [US2] Estender src/game/gameplay_manager.gd: instanciar RaceProgression no `_ready`; conectar `continue_next_phase`; no encerramento por vitória chamar `progresso.registra_vitoria()` antes de `game_state.victory()`; na derrota `progresso.zerar_ciclo_por_derrota()` antes de `game_state.game_over()`; handler `_on_continue_next_phase` (sync `GameConfig.current_environment_id` + `aplicar_fator_ciclo` + `_aplicar_sprite_selecionado` + `_reset_corrida` + `start_game()`); sync de ambiente também em `_on_start_race` (contracts/environment_cycle.md §2–§3)
- [X] T016 [P] [US2] Criar tests/unit/cycle_flow_test.gd: vitória tem exatamente 2 opções e Game Over exatamente 1; `continue_next_phase` inicia corrida no ambiente seguinte com tanque cheio/distância zerada; derrota em qualquer ambiente → próxima corrida em PLAINS; ciclos concluídos preservados após derrota (SC-014/017)

**Checkpoint**: US1+US2 — corrida infinita navegável por menus de fim

---

## Phase 5: User Story 3 - Balancear trânsito, galões e penalidades pelo modo (Priority: P3)

**Goal**: modo escala densidade de trânsito, frequência/distância de galões e penalidade de colisão, respeitando limites absolutos (piso/teto de NPCs, zero não-negativo).

**Independent Test**: quickstart §3.3 — Relaxante menos carros/mais galões/menos penalidade, Desafio o inverso sem violar teto de 12; suítes `difficulty_traffic_can_test` + penalidade em `difficulty_fuel_test` verdes.

### Tests for User Story 3

- [X] T017 [P] [US3] Criar tests/unit/difficulty_traffic_can_test.gd: densidade 0,70 < 1,00 < 1,20 de NPCs visíveis dentro de `traffic_min_visible..traffic_max_vehicles` (SC-005); ordem de frequência de galões Relaxante > Normal > Desafio e intervalo efetivo sempre > 0 (SC-006); piso/teto intactos nos extremos

### Implementation for User Story 3

- [X] T018 [US3] Estender src/traffic/traffic_manager.gd: `_maximo_visivel_atual()` = `teto_ambiente × fator_densidade` com `clamp(..., traffic_min_visible, traffic_max_vehicles)` — leitura única no `_tentar_gerar` (R5)
- [X] T019 [US3] Estender src/items/fuel_can_manager.gd: campos `dificuldade` (ref) e fallback 1.0; aplicar `fator_freq` na taxa de spawn e `fator_dist` no intervalo de distância em `_tentar_gerar` (R6)
- [X] T020 [US3] Estender src/fuel/fuel_system.gd: campo `fator_penalidade_colisao` (default 1.0); `on_player_collision` aplica penalidade do ambiente × fator, nunca negativa (R7, FR-010, SC-007)
- [X] T021 [US3] Estender tests/unit/difficulty_fuel_test.gd (parte penalidade): penalidade = ambiente × modo (Desafio 1,5×; Relaxante 0,5×), aplicação única por colisão, penalidade base 0 × fator = 0 (SC-007)

**Checkpoint**: US1–US3 — balanceamento completo por modo

---

## Phase 6: User Story 4 - Combinar o modo com qualquer ambiente e integrar a seleção da SPEC-013 (Priority: P4)

**Goal**: modo e ambiente ortogonais — qualquer combinação funciona sem quebra; superfície da SPEC-013 (`select_next_mode`, `atualizar_modo`, API do DifficultyManager) estável; combustível coerente em alta velocidade.

**Independent Test**: quickstart passos 18–20 (§3.4–§3.5) — 12 combinações ambiente×modo, desaceleração/game over/vitória em 3×/4×; suíte `difficulty_environment_matrix_test` verde.

### Tests for User Story 4

- [X] T022 [P] [US4] Criar tests/unit/difficulty_environment_matrix_test.gd: os 4 ambientes × 3 modos — fatores de modo idênticos em qualquer ambiente, características ambientais (penalidades base, densidades de galões por ambiente) inalteradas pelo modo além dos fatores, modos mutuamente independentes (SC-011)

### Implementation for User Story 4

- [X] T023 [US4] Conferir contrato da superfície SPEC-013: `select_next_mode`/`atualizar_modo`/API do DifficultyManager estáveis e documentados em contracts/ui_commands.md e contracts/difficulty_manager_api.md — nenhuma mudança de interface na fase de implementação (FR-018; a SPEC-013 só consome)

**Checkpoint**: 4 US independentes e combináveis

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: regressão global, documentação e pendências manuais

- [X] T024 [P] Criar tests/unit/difficulty_stability_test.gd: cenário máximo (Desafio 4,0× + densidade 1,20×) — 0 travamentos, 0 crescimento indefinido de NPCs ou galões em corridas longas e ciclos simulados, nenhuma corrida de referência inconcluível (SC-013)
- [X] T025 [P] Criar tests/unit/difficulty_state_flow_test.gd: transições `MENU`/`READY`/`PLAYING`/`PAUSED`/`VICTORY`/`GAME_OVER` em cada um dos 3 modos funcionam; pausa/retomada alteram o multiplicador em 0 ensaios; reinício reaplica a configuração em 100% dos casos (SC-010)
- [X] T026 Rodar suíte completa headless: `GODOT_BIN=$HOME/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64 bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit` — as 50 suítes legadas devem permanecer verdes **sem qualquer ajuste** (garantia R12); novas suítes `difficulty_*`/`cycle_*` verdes; exit 101
- [X] T027 [P] Atualizar seção "Estado atual" do AGENTS.md com o status da SPEC-009 (tarefas concluídas, suíte completa, pendências manuais)
- [X] T028 Aceite manual do usuário: quickstart.md §3.1–§3.5 (20 passos) + calibração §5 se a sensação de sobra de combustível/dificuldade exigir ajustar fatores do bloco config — **bloqueio do usuário**, registrar resultados em uma fase de aceite manual ao final deste arquivo (padrão SPECs anteriores — ex.: "Phase 13: Ajustes pós-implementação" da SPEC-008) — executado em 2026-10-16, ver Phase 11

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — iniciar imediatamente
- **Foundational (Phase 2)**: depende do T001 — BLOQUEIA todas as US
- **US1 (Phase 3)**: depende do Phase 2 — sem dependências de outras US
- **US2 (Phase 4)**: depende do Phase 2; integra com US1 (fator de velocidade injetado) mas é testável de forma independente
- **US3 (Phase 5)**: depende do Phase 2; usa os mesmos pontos de injeção da US1 (density/cans/penalidade), sem dependência funcional da US2
- **US4 (Phase 6)**: depende das US 1–3 para o matricial; o contrato de superfície (T023) pode ser conferido a partir do Phase 2
- **Polish (Phase 7)**: depende das US desejadas (MVP = US1); a suíte de estabilidade (T024) exige US1+US3 implementadas

### User Story Dependencies

- **US1 (P1)**: após Foundational — independente
- **US2 (P2)**: após Foundational — independente (fator de ciclo passa a existir, mas a progressão se valida sem ele)
- **US3 (P3)**: após Foundational — independente (fatores default 1,0 mantêm o jogo em Normal)
- **US4 (P4)**: integração das três + matricial

### Within Each User Story

- Testes escritos primeiro (devem falhar antes da implementação)
- Componentes/`RefCounted` novos antes do wiring no `gameplay_manager.gd`
- Config (T001) → Foundation (T002–T003) → impl da história → testes da história → aceite manual

### Parallel Opportunities

- T001 (Setup) sozinho, imediatamente
- T002 ∥ T003 após T001 (implementação vs suíte do componente — mesmo arquivo? não: src vs tests)
- US1: T004 ∥ T005 ∥ T006 ∥ T007 (arquivos distintos); depois T008 (mesmo arquivo de T004) e T011
- US2: T012 ∥ T013; depois T014 → T015 → T016
- US3: T017 sozinho; depois T018 ∥ T019 ∥ T020 (arquivos distintos) → T021
- US4: T022 ∥ T023
- Polish: T024 ∥ T025 (arquivos distintos); depois T026 → T027 → T028
- Histórias US2/US3/US4 podem rodar em paralelo entre si após Foundational (toques em arquivos distintos, exceto gameplay_manager.gd compartilhado — serializar os wirings T011/T015)

---

## Parallel Example: User Story 1

```bash
# Juntos (arquivos distintos, após T002–T003):
Task: "tests/unit/difficulty_speed_test.gd (T004)"
Task: "tests/unit/difficulty_fuel_test.gd — consumo (T005)"
Task: "src/player/vehicle_controller.gd (T006)"
Task: "src/traffic/traffic_vehicle.gd (T007)"

# Em sequência por conflito de arquivo:
Task: "src/traffic/traffic_manager.gd (T008)"
Task: "src/fuel/fuel_system.gd (T009)"
Task: "src/ui/ui_manager.gd (T010)"
Task: "src/game/gameplay_manager.gd (T011 — wiring final)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 (T001) + Phase 2 (T002–T003)
2. Phase 3 completa (T004–T011)
3. **PARAR E VALIDAR**: quickstart §3.1–§3.2 + suíte headless
4. Nesse ponto o jogo tem 3 modos de velocidade — valor entregue sozinho

### Incremental Delivery

1. Setup + Foundational → DifficultyManager pronto
2. + US1 → modos de velocidade (MVP)
3. + US2 → progressão infinita com telas de fim
4. + US3 → balanceamento de trânsito/galões/penalidades
5. + US4 → matricial e superfície SPEC-013
6. Polish → regressão global, docs, aceite/calibração manual

### Notes

- [P] = arquivos distintos, sem dependências entre tarefas pendentes
- Cada tarefa de wiring no `gameplay_manager.gd` serializa (mesmo arquivo)
- Fallback 1,0 em todo ponto de injeção garante que a regressão de 324 casos rode sem tocar nas suítes legadas
- Pendências manuais (T028) seguem o padrão T053/T055 da SPEC-008 — ficam `[ ]` até o usuário rodar o quickstart

---

## Phase 8: Convergence

- [X] T029 Estender o cenário máximo de tests/unit/difficulty_stability_test.gd para reproduzir a ordem canônica do quadro (`npc_collision_system.update` e `collision_system.update` junto de trânsito/itens, como `_processar_playing`) e acrescentar cobertura de colisão NPC×NPC com fator de velocidade 3×/4×, sem atravessamento e com evento único — per SC-013, SC-009 e FR-014 (partial)
- [X] T030 Criar teste de corrida de referência automatizada para as 12 combinações (4 ambientes × 3 modos): executar os updates de trânsito, galões, combustível e pista em cada combinação sem falha de script — per SC-011 (partial)
- [X] T031 Criar teste automatizado do menu de 3 linhas: navegação `wrapi(0,3)`, rótulo inicial "Modo: Normal", `ui_accept` na linha 1 emite `select_next_mode` e `atualizar_modo` reflete o novo rótulo — per FR-016, US1/AC9 (partial)
- [X] T032 Acrescentar à suíte de estabilidade a contagem de nascimentos de NPCs ao longo do tempo (nascimentos seguem ocorrendo após reinício e em corrida longa — 0 bloqueios permanentes) — per SC-005 (partial)
- [X] T033 Atualizar a tabela de validação automatizada do quickstart.md (§4) para listar as 9 suítes novas — faltam `difficulty_environment_matrix_test`, `difficulty_stability_test` e `difficulty_state_flow_test` — per plan.md Testing (partial)

## Phase 9: Convergence

- [X] T034 Criar teste sintético da composição do seletor no orquestrador: montar GameplayManager com `dificuldade` e `ui_root` em árvore, chamar `_on_select_next_mode()` nos 3 modos e conferir o ciclo de modo (`relaxing` → `normal` → `challenge`) e o rótulo devolvido por `_rotulo_modo()` (chaves `mode_<id>` de `GameConfig.ui_strings`), além das guardas de `dificuldade == null`/`ui_root` nulo — per FR-016, US1/AC9 (partial)
- [X] T035 Corrigir em plan.md a linha do Constitution Check "Testes", que alega cobertura por "Critérios 12.1–12.5" inexistentes na constituição v3.0.0 (§`### Testes` não tem subcritérios numerados 12.x), citando a seção real e mantendo a evidência já válida (suítes novas + aceite manual do quickstart) — per plan.md Constitution Check — Testes (contradicts)
- [X] T036 Corrigir em tasks.md o texto do T028, que aponta "registrar resultados em tasks.md Phase 13" (fase inexistente neste arquivo — próximas fases são 9+), para registrar o aceite manual na fase de aceite manual a ser criada ao final deste arquivo — per tasks.md T028 (contradicts)

## Phase 10: Ajustes pós-implementação (2026-10-14)

- [X] T037 [correção] Menu de pausa do ESC não aparecia durante a corrida: o mesmo `ui_cancel` que pausava continuava "just pressed" no quadro da virada PLAYING → PAUSED e a UI retomava no mesmo quadro (o painel — e a opção "Voltar ao menu" — nunca era desenhado). Guarda de quadro nos dois lados: `_frame_pausa` em `src/ui/ui_manager.gd` (`_aplicar_estado`/`_process_pausa`) e `_frame_play` em `src/game/gameplay_manager.gd` (`_show_playing`/`_processar_playing`), tornando o resultado independente da ordem de processamento entre os nós — per contracts/ui_commands.md §3, FR-034
- [X] T038 [ajuste] Adendo de 2026-10-14 (spec.md Clarifications): Normal 2,0× → **3,0×** e Desafio 3,0× → **4,0×** (quádruplo) em `src/config/game_config.gd` — Relaxante e os demais 4 fatores por modo inalterados; valores propagados nas suítes `difficulty_manager_test`, `difficulty_environment_matrix_test`, `difficulty_state_flow_test`, `difficulty_speed_test` e `difficulty_stability_test` (cenário máximo 4,0×) e no texto de spec/plan/quickstart/research/data-model/tasks — per FR-001, SC-001, SC-013

## Phase 11: Aceite manual (2026-10-16)

**Purpose**: Execução do quickstart §3.1–§3.5 pelo usuário no build completo (inclui os ajustes da Phase 10 — guarda de quadro do ESC e multiplicadores 3,0×/4,0×); registro exigido pelo T028.

- [X] T028 Aceite manual do usuário — **sem problemas identificados**:
  - **§3.1 Menu e seleção de modo** (passos 1–4): menu com 3 linhas e destaque navegável, ciclo Relaxante → Normal → Desafio no rótulo "Modo", largada em Normal sem aceleração instantânea e sem acúmulo de velocidade entre corridas.
  - **§3.2 Os três modos (velocidade)** (passos 5–8): Relaxante 1,0× idêntico à base (regressão zero), Normal 3,0×, Desafio 4,0× com colisões continuamente detectadas e pausa congelando tudo; direção e resposta de aceleração/frenagem inalteradas entre modos.
  - **§3.3 Balanceamento por modo** (passos 9–11): densidade, frequência de galeões e penalidade de colisão na ordem esperada por modo; corrida de referência de 5 km **concluível nos 3 modos** com sobra de combustível dentro da faixa — nenhum caso de inconcluibilidade a registrar.
  - **§3.4 Progressão infinita** (passos 12–18): vitória com exatamente 2 opções, "Continuar próxima fase" avançando planície → deserto → floresta → gelo → planície com tanque cheio, bônus de ciclo por suíte `cycle_*`, derrota levando ao fim de jogo com apenas "Voltar ao menu" e reinício na planície, e as 12 combinações ambiente × modo sem quebra.
  - **§3.5 Combustível e estados** (passos 19–20): esgotamento em 3,0×/4,0× levando ao `GAME_OVER` com desaceleração gradual, vitória exigindo combustível na chegada, pausa/retomada sem alterar multiplicadores e nenhum sistema avançando no menu (guarda de quadro do ESC da Phase 10 funcionando — painel de pausa com "Voltar ao menu" visível).
  - **Calibração §5**: **não acionada** — nenhum ajuste dos fatores do bloco `difficulty_modes`/`difficulty_*` em `src/config/game_config.gd` foi necessário; sementes mantidas como estão.
  - **Suíte completa na mesma data**: 63 suítes, 388 casos, **exit 101** (verde).
