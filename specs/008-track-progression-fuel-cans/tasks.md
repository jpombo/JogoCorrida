---

description: "Task list template for feature implementation"
---

# Tasks: Progressão da Pista, Estados do Jogo, Combustível e Itens Coletáveis (SPEC-008)

**Input**: Design documents from `/specs/008-track-progression-fuel-cans/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: **OBRIGATÓRIOS** — a spec exige explicitamente os 9 testes do texto-fonte (A–I; Assumptions: "Testes obrigatórios"), cobertos pelas suítes: A+B → `track_progression_test.gd`, C → `track_finish_test.gd`, D → `fuel_sizing_test.gd`, E → `fuel_can_collection_test.gd`, F → `fuel_can_generation_test.gd`, G → `fuel_game_over_flow_test.gd`, H → `ui_screens_test.gd` + `race_reset_test.gd`, I → `race_reset_test.gd` + `game_config_008_test.gd`.

**Organization**: Tarefas agrupadas por user story para implementação e teste independentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: User story da tarefa (ex.: US1, US2)
- Caminhos exatos em cada descrição (convenção: `src/`, `tests/` na raiz)

## Path Conventions

- Projeto único Godot 4.7: `src/`, `tests/unit/` na raiz do repositório
- Parâmetros e eventos conforme `data-model.md` §6 e `contracts/` (prefixos `track_`, `fuel_can_`, `ui_`)
- Decisões de design: `research.md` R1–R13

---

## Phase 1: Setup (Infraestrutura Compartilhada)

**Purpose**: Bloco de configuração e esqueletos dos novos módulos — base compartilhada de todas as stories

- [X] T001 Add bloco `## Progressão e Itens (SPEC-008)` em src/config/game_config.gd com os parâmetros de data-model.md §6 (`track_total_distance=5.0`, `track_units_to_km=0.00034722`, `fuel_consumption_per_distance=40.0`, `fuel_safety_margin=60.0`, `fuel_can_restore_amount=25.0`, `fuel_can_spawn_interval_distance=0.35`, `fuel_can_min_spacing=120.0`, `fuel_can_npc_spacing=24.0`, `fuel_can_start_offset=0.15`, `fuel_can_finish_offset=0.25`, `fuel_can_max_active=3`, `fuel_can_min_per_race=4`, `fuel_can_max_per_race=12`, `fuel_can_spawn_rate={PLAINS:1.4, DESERT:1.0, FOREST:0.7, ICE:0.5}`) e rótulos `ui_*` (`ui_menu_title`, `ui_select_vehicle`, `ui_vehicle_blue`, `ui_vehicle_red`, `ui_start_label`, `ui_start_marker_label="INÍCIO"`, `ui_finish_marker_label="CHEGADA"`, `ui_distance_format="Distância: %.1f km / %.1f km"`, `ui_victory_label`, `ui_game_over_label`, `ui_pause_label`, `ui_btn_continue="Continuar"`, `ui_btn_restart="Reiniciar"`, `ui_btn_try_again="Tentar novamente"`, `ui_btn_menu="Voltar ao menu"`) — sementes CALIBRAÇÃO de research.md R13
- [X] T002 [P] Create esqueleto de src/track/track_manager.gd com `extends Node`, `class_name TrackManager`, sinal `progress_changed(percorrida: float, total: float, percentual: float)` e stubs (`setup`, `reset`, `update`, `marcar_concluido`, getters) — assinaturas exatas de contracts/track_progression.md
- [X] T003 [P] Create esqueleto de src/track/track_markers.gd com `extends Node2D`, `class_name TrackMarkers`, enum `INICIO/CHEGADA` e stubs (`criar_marcadores`, `update`, `reset`, helper de vitória `banda_completamente_cruzou`) — data-model.md §3
- [X] T004 [P] Create esqueleto de src/items/fuel_can.gd com `extends Node2D`, `class_name FuelCan`, enum `ATIVO/COLETADO`, `Sprite2D` + área de contato própria e stubs (`ativar`, `reset_para_pool`) — data-model.md §4
- [X] T005 [P] Create esqueleto de src/items/fuel_can_manager.gd com `extends Node2D`, `class_name FuelCanManager`, sinais `fuel_can_spawned(can)` e `fuel_can_collected(restaurado: float)`, campos `pool/ativos/gerados_na_corrida/distancia_desde_ultima/spawn_pendente` e stubs (`setup`, `update`, `reset`) — contracts/fuel_can_lifecycle.md
- [X] T006 [P] Create esqueleto de src/ui/ui_manager.gd com `extends Control`, `class_name UIManager`, sinais `start_race/select_next_vehicle/continue_race/restart_race/go_to_menu` e stubs (`setup`, `_on_state_changed`, `_on_progress_changed`) — contracts/ui_commands.md

---

## Phase 2: Foundational (Pré-requisito Bloqueante)

**Purpose**: Extensões do FuelSystem, flag de combustível no controlador e resets dos sistemas existentes — base que TODAS as stories dependem

**⚠️ CRITICAL**: Nenhuma user story começa antes desta fase

- [X] T007 Implement extensão de capacidade em src/fuel/fuel_system.gd: campo `_capacidade_derivada=-1.0`, `definir_capacidade_derivada(cap)` (negativo limpa) e `reset()` usando o override se `>= 0` senão `GameConfig.fuel_capacity`, preservando sentinela de inicial, clamps e emissões — contracts/fuel_restoration.md §1 (depends: T001)
- [X] T008 [P] Implement `restaurar(valor: float)` em src/fuel/fuel_system.gd: `_escrever(clamp(_atual + max(valor, 0), 0, _capacidade))` — no-op silencioso com tanque cheio, sem rearme de latches, sem `fuel_depleted` — contracts/fuel_restoration.md §2 (depends: T007)
- [X] T009 [P] Add flag `aceleracao_bloqueada_por_combustivel: bool = false` em src/player/vehicle_controller.gd, checada em conjunto com `aceleracao_bloqueada` no ramo de aceleração de `_apply_vertical_physics` (frenagem/desaceleração natural intactas) e limpa em `reset()` — research.md R5 (depends: —)
- [X] T010 [P] Add `reset()` em src/road/road.gd: `scroll_speed=0`, `scroll_offset=0` — research.md R10/R11 (depends: —)
- [X] T011 [P] Add `reset()` em src/traffic/traffic_manager.gd: pool/ativos/reciclagem/`_cronometro_spawn`/`_habilitado`/`_spawn_pendente` restaurados ao estado de largada — research.md R10 (depends: —)
- [X] T012 [P] Add `reset()` em src/collision/collision_system.gd: cooldowns e conjuntos de sobreposição limpos — research.md R10 (depends: —)
- [X] T013 [P] Add `reset()` em src/collision/npc_collision_system.gd: drifts, cadeias, janelas, cooldowns e flags de reavaliação limpos — research.md R10 (depends: —)
- [X] T014 [P] Add `reset()` em src/decoration/decoration_manager.gd: elementos e baseline de scroll restaurados — research.md R10 (depends: —)
- [X] T015 [P] Add `reset()` em src/player/player_vehicle.gd: delega a `controller.reset()` (existente), restaura `position` inicial e reaplica o sprite selecionado — research.md R10 (depends: T009)
- [X] T016 Implement orquestrador de reset em src/game/gameplay_manager.gd: função `_reset_corrida()` chamada exclusivamente na transição READY → PLAYING, invocando `reset()` de Road, Traffic, CollisionSystem, NpcCollisionSystem, DecorationManager, PlayerVehicle e (quando existirem) TrackManager/TrackMarkers/FuelCanManager/UI — conexões de sinais permanecem só no `_ready` (SC-012) — contracts/game_state_transitions.md §3 (depends: T007, T010–T015)

**Checkpoint**: Fundação pronta — as 8 user stories podem começar

---

## Phase 3: User Story 1 - Iniciar, pausar e encerrar corridas pelo menu (Priority: P1) 🎯 MVP

**Goal**: Ciclo completo da sessão: menu com seleção azul/vermelho (padrão azul, sem atributos distintos), largada limpa, pausa com freeze real (rolagem zerada) e telas de fim/pausa com "Continuar", "Reiniciar" e "Voltar ao menu"; reinício e menu sem resíduos

**Independent Test**: Abrir → MENU; selecionar cada veículo; iniciar → corrida limpa; pausar → nada avança (rolagem incluída); retomar sem salto; encerrar → Reiniciar/Voltar ao menu sem resíduos nem conexões repetidas

### Tests for User Story 1 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T017 [P] [US1] Create tests/unit/ui_screens_test.gd cobrindo o teste obrigatório H (telos): estado inicial MENU, painel correto em cada `state_changed` (MENU/READY/PLAYING/PAUSED/VICTORY/GAME_OVER), opções exigidas visíveis ("Continuar"/"Reiniciar"/"Voltar ao menu" na pausa; "Tentar novamente"/"Voltar ao menu" nos fins), textos vindos de `GameConfig.ui_*`, UI não escreve em gameplay (SC-017/SC-001/SC-015) — instanciar `ui_manager.gd` headless conforme contracts/ui_commands.md
- [X] T018 [P] [US1] Create tests/unit/race_reset_test.gd cobrindo o teste obrigatório H (ciclo de vida) e parte de I: `_reset_corrida()` zera Road (scroll), Player (velocidade/posição), Traffic (ativos), FuelSystem (tanque cheio) e Track/Cans quando existirem; 2 resets consecutivos sem duplicatas; conexões de sinais não se acumulam (SC-012/SC-003/SC-013) — instanciar `gameplay_manager.gd` sem árvore, injetar sistemas e chamar o orquestrador diretamente (padrão da SPEC-007)

### Implementation for User Story 1

- [X] T019 [US1] Implement src/ui/ui_manager.gd: `MenuPanel` (título + seleção de veículo azul/vermelho + "Iniciar"), navegação por `ui_left/right` + `ui_accept` emitindo `select_next_vehicle`/`start_race`, textos 100% de `GameConfig.ui_*` — research.md R12 (depends: T001, T006)
- [X] T020 [US1] Implement src/ui/ui_manager.gd: `PausePanel` com "Continuar", "Reiniciar", "Voltar ao menu" emitindo `continue_race`/`restart_race`/`go_to_menu`; `ui_cancel` = Continuar (atalho atual preservado) — contracts/ui_commands.md §1 (depends: T019)
- [X] T021 [US1] Implement src/ui/ui_manager.gd: `VictoryPanel` e `GameOverPanel` com "Tentar novamente"/"Voltar ao menu", mostrados/escondidos por `state_changed` — research.md R12 (depends: T019)
- [X] T022 [US1] Wire seleção e comandos em src/game/gameplay_manager.gd: campo `_veiculo_selecionado` (padrão `azul`, persiste na sessão), `change_sprite` via `GameConfig.default_sprite_path`/`alt_sprite_path`, handlers dos sinais da UI (start → `GameState.start_game()`, continue → `resume_game()`, restart → `_reset_corrida()` + `start_game()`, menu → reset de encerramento + `GameState.reset()`) — research.md R12, FR-002/SC-001 (depends: T019–T021)
- [X] T023 [US1] Implement freeze de pausa em src/game/gameplay_manager.gd: em `PAUSED`, `road.update_scroll_speed(0.0)`; em `PLAYING` o ramo continua alimentando a rolagem; em `MENU`/fim, mundo escondido e nada avança — research.md R11, FR-004/FR-036 (depends: T010, T022)
- [X] T024 [US1] Extend src/game/gameplay.tscn: novo `CanvasLayer` de UI com UIManager (painéis montados por construção de código ou nós filhos), posicionado após o `FuelHudLayer` — FR-034/SC-017 (depends: T019–T021)
- [X] T025 [US1] Complete `_reset_corrida()` em src/game/gameplay_manager.gd para chamar `ui_manager.reset()`/estado inicial de painéis e garantir que "Reiniciar"/"Tentar novamente" produzam corrida limpa em QUALQUER estado anterior (READY/PAUSED/VICTORY/GAME_OVER) — caso de borda "Reinício durante qualquer estado", SC-012 (depends: T016, T022)

**Checkpoint**: US1 funcional — MVP jogável do menu ao reinício (sem distância/vitória/galões ainda)

---

## Phase 4: User Story 2 - Percorrer a distância da pista com início e chegada visíveis (Priority: P1)

**Goal**: Distância finita configurável que cresce só com o avanço (faixa soma zero; parado/pausado não acumula; nunca ultrapassa o total), indicador na UI e marcações `INÍCIO`/`CHEGADA` no mundo da pista

**Independent Test**: Acelerar/parar/trocar de faixa e medir o indicador; pausar/retomar sem salto; observar INÍCIO sumir da tela e CHEGADA aproximar-se pela rolagem

### Tests for User Story 2 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T026 [P] [US2] Create tests/unit/track_progression_test.gd cobrindo os testes obrigatórios A e B: `reset()` em zero; crescimento com velocidade sintética; 0 crescimento com velocidade zero; **0 crescimento com movimento lateral apenas** (Clarificação de faixa); clamp ao total; independência de reciclagem de segmentos; `progress_changed` só em variação; desvio < 1% entre taxas de quadro — instanciar `TrackManager.new()` conforme contracts/track_progression.md
- [X] T027 [P] [US2] Create tests/unit/track_finish_test.gd cobrindo a parte do teste C relativa ao marcador: `CHEGADA` posicionada em `player_y − total / track_units_to_km`, desloca-se com `scroll_speed × delta`, banda construída com primitivas, rótulo de `GameConfig`, `INÍCIO` descartada definitivamente ao sair da tela (0 reaparecimentos), e posições das bandas idênticas antes e depois de uma pausa→retomada (update sem rolagem não desloca — SC-012) — instanciar `track_markers.gd` headless com um `Road` sintético

### Implementation for User Story 2

- [X] T028 [US2] Implement núcleo de src/track/track_manager.gd: `setup(total)`, `reset()` (zero + emissão inicial), `update(delta, velocidade_avanco)` com `percorrida = min(percorrida + v × track_units_to_km × delta, total)`, `restante`/`percentual` derivados, emissão com `is_equal_approx`, getters e `marcar_concluido()` — research.md R1, data-model.md §2 (depends: T001, T002)
- [X] T029 [US2] Implement src/track/track_markers.gd: construção de banda quadriculada + `Label` (ColorRect/Label, escala inteira, `TEXTURE_FILTER_NEAREST`), `INÍCIO` nascendo na largada e ocultada definitivamente ao sair da tela, `CHEGADA` posicionada no fim lógico, `update(delta, scroll)` movendo ambos pela rolagem — research.md R2, FR-010/FR-011 (depends: T003)
- [X] T030 [US2] Wire progressão e marcadores em src/game/gameplay_manager.gd e src/game/gameplay.tscn: instanciar `TrackManager`/`TrackMarkers` (TrackLayer na cena), chamar `track_manager.update(_delta, player_vehicle.get_speed())` no ramo `PLAYING` (passo 5 da ordem canônica de contracts/game_state_transitions.md §2), criar marcadores em READY→PLAYING e resetar no `_reset_corrida()` — research.md R9/R10 (depends: T016, T028, T029)
- [X] T031 [US2] Implement indicador de distância em src/ui/ui_manager.gd: `DistanceIndicator` (rótulo + barra) observando `progress_changed`, formato de `GameConfig.ui_distance_format`, largura da barra por `percentual`, congela quando as emissões param (pausa/fim) — research.md R12, FR-009/SC-004 (depends: T028)

**Checkpoint**: US2 funcional — corrida com progresso medido e marcações visíveis

---

## Phase 5: User Story 3 - Vencer ao cruzar a linha de chegada com combustível (Priority: P1)

**Goal**: `VICTORY` exatamente uma vez no cruzamento **completo** da banda com combustível > 0 e `PLAYING`; esgotamento tem precedência no mesmo quadro; progressão/consumo param

**Independent Test**: Cruzar com combustível → `VICTORY` 1×; cruzar sem combustível ou fora de `PLAYING` → nada; tentar vencer duas vezes → 1 evento

### Tests for User Story 3 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T032 [US3] Extend tests/unit/track_finish_test.gd com os cenários de vitória do teste C: cruzamento completo com combustível ⇒ transição 1×; combustível zero no instante ⇒ sem vitória (precedência do esgotamento); fora de `PLAYING` ⇒ sem avaliação; banda ainda no jogador ⇒ sem vitória (cruzamento efetivo, não `percorrida == total`) — caso de borda 14 (depends: T027)

### Implementation for User Story 3

- [X] T033 [US3] Implement checagem de vitória em src/game/gameplay_manager.gd (passo 6 da ordem canônica): geometria `banda.top_y >= player_y + hitbox.y/2` via helper de `TrackMarkers`, com as quatro condições de FR-013 no instante — research.md R2/R9 (depends: T029, T030)
- [X] T034 [US3] Wire `GameState.victory()` + `track_manager.marcar_concluido()` + sinal `race_won` em src/game/gameplay_manager.gd, com guarda de corrida não encerrada (`change_state` no-op) e interrupção de progresso/consumo/rolagem na virada — contracts/game_state_transitions.md §1, FR-014/SC-005 (depends: T033)

**Checkpoint**: US3 funcional — pista finita vencível com combustível

---

## Phase 6: User Story 4 - Sofrer a falta de combustível até a parada e o Game Over (Priority: P1)

**Goal**: Com zero: sem novas acelerações (flag derivada do valor), desaceleração gradual, distância ainda crescendo, `GAME_OVER` 1× ao parar sem concluir; coleta durante desaceleração reabilita (sem rearme de evento)

**Independent Test**: Zerar → aviso único, sem acelerar, desacelera; parar → `GAME_OVER` 1×; coletar durante a desaceleração → acelera de novo; coleta após `GAME_OVER` não reativa

### Tests for User Story 4 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T035 [P] [US4] Create tests/unit/fuel_game_over_flow_test.gd cobrindo o teste obrigatório G: flag de bloqueio ligada com zero e desligada após `restaurar` em `PLAYING`; desaceleração gradual até zero (não instantânea); distância cresce durante a desaceleração; `GAME_OVER` 1× ao parar com zero e sem concluir; `restaurar` em `PLAYING` reabilita sem novo `fuel_depleted` (sem rearme); `restaurar` com estado `GAME_OVER` não reativa; 0 eventos adicionais de Game Over — combinar `FuelSystem` estendido + `VehicleController` + transições sintéticas do `GameplayManager` (depends: T007–T009)

### Implementation for User Story 4

- [X] T036 [US4] Wire flag de combustível em src/game/gameplay_manager.gd: a cada quadro do ramo `PLAYING` **após** o consumo, `player_vehicle.controller.aceleracao_bloqueada_por_combustivel = fuel_system.get_atual() <= 0.0`; limpa no `_reset_corrida()` — research.md R5/R9 (depends: T009, T016)
- [X] T037 [US4] Implement trigger de `GAME_OVER` em src/game/gameplay_manager.gd (passo 6, após a checagem de vitória): `combustível == 0 and speed == 0 and não concluída` ⇒ `GameState.game_over()` + sinal `race_lost`; ramo `PLAYING` deixa de rodar na virada (nunca revertido) — contracts/game_state_transitions.md §1, FR-016/SC-005/SC-007 (depends: T034, T036)

**Checkpoint**: US4 funcional — regra central "chegar antes de ficar sem combustível" completa

---

## Phase 7: User Story 5 - Dimensionar o combustível pela distância total (Priority: P1)

**Goal**: Capacidade e carga inicial derivadas em execução (`distância × consumo_base_por_unidade + margem`), sem dupla fonte de verdade, corrida de referência concluível com folga

**Independent Test**: Alterar `track_total_distance` → tanque muda automaticamente; corrida sem colisões/coletas termina com sobra na faixa; nada reforça combustível automaticamente

### Tests for User Story 5 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T038 [P] [US5] Create tests/unit/fuel_sizing_test.gd cobrindo o teste obrigatório D: capacidade = inicial = `distância × consumo_por_km + margem` calculada no início da corrida; alterar a distância muda o tanque sem tocar na lógica; corrida sintética de referência (velocidade constante, sem colisões/coletas) cruza o total com sobra dentro da faixa 15%–35%; capacidade derivada respeita limites (`>= 0`, guard de config inválida); sem chamada de dimensionamento, o caminho SPEC-007 permanece idêntico (regressão) — depends: T007

### Implementation for User Story 5

- [X] T039 [US5] Implement fórmula de dimensionamento em src/game/gameplay_manager.gd na transição READY → PLAYING (antes do reset): `estimado = GameConfig.track_total_distance × fuel_consumption_per_distance + fuel_safety_margin` → `fuel_system.definir_capacidade_derivada(estimado)` → `fuel_system.reset()` — research.md R3, FR-018/FR-019 (depends: T007, T016)
- [X] T040 [US5] Add guard de config inválida em src/game/gameplay_manager.gd: `track_total_distance <= 0` limita aos limites válidos (sem divisão por zero, sem conclusão instantânea); capacidade derivada sempre `>= 0` — caso de borda "Erro de configuração", SC-006/SC-008 (depends: T039)

**Checkpoint**: US5 funcional — balanceamento de combustível acoplado à pista apenas por configuração

---

## Phase 8: User Story 6 - Coletar galões de gasolina na pista (Priority: P2)

**Goal**: Galões no mundo da pista, sem velocidade própria (só rolagem), coleta 1× em `PLAYING` com cap no máximo e **zero efeitos de colisão**; não coletado que sai da tela volta ao pool e é reapresentado

**Independent Test**: Gerar/posicionar um galão alcançável, encostar → some na hora, combustível sobe (cap cheio mantém), sem duplicatas, sem colisão; passar por ele → reciclado mais adiante

### Tests for User Story 6 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T041 [P] [US6] Create tests/unit/fuel_can_collection_test.gd cobrindo o teste obrigatório E: sobreposição em `PLAYING` ⇒ 1 coleta + 1 `fuel_can_collected` mesmo com contato por vários quadros; `restaurar` com `min(atual + recuperado, capacidade)`; tanque cheio ⇒ galão some e valor permanece; fora de `PLAYING` ⇒ sem coleta; **0 consequências de colisão** (velocidade/deriva/penalidade/cooldown/eventos intactos); não coletado que sai pela base ⇒ devolvido ao pool e reapresentável com estado redefinido; parado ⇒ galão parado (Clarificação de velocidade); e posição/estado do galão ativo idênticos antes e depois de uma pausa→retomada (SC-012) — instanciar `FuelCanManager` + `FuelSystem` headless conforme contracts/fuel_can_lifecycle.md (depends: T008)

### Implementation for User Story 6

- [X] T042 [P] [US6] Implement src/items/fuel_can.gd: textura `res://assets/decoracao/gasolina.png` (32×51, `TEXTURE_FILTER_NEAREST`, sem redesenho), área de contato própria centrada, estados `ATIVO/COLETADO`, `ativar(posicao)`/`reset_para_pool()` zerando estado e referências — research.md R8, FR-021/FR-031 (depends: T004)
- [X] T043 [US6] Implement src/items/fuel_can_manager.gd: `setup()` com pool de `fuel_can_max_active` instâncias; `update()` movendo ativos por `y += road.scroll_speed × delta` (sem velocidade própria), reciclagem na base com devolução ao pool e `reset()` completo — research.md R7/R8, FR-023/FR-031 (depends: T005, T042)
- [X] T044 [US6] Implement coleta em src/items/fuel_can_manager.gd: teste de interseção retângulo galão×hitbox do jogador no final do quadro, marcação `COLETADO` + devolução imediata + emissão de `fuel_can_collected(fuel_can_restore_amount)` 1×; **não** passa pelo `CollisionSystem` — research.md R8, FR-024/SC-009 (depends: T043)
- [X] T045 [US6] Wire galões em src/game/gameplay_manager.gd e src/game/gameplay.tscn: `ItemsLayer` na cena, `fuel_can_manager.update(...)` no passo 3 da ordem canônica **antes** do consumo, `fuel_can_collected.connect(fuel_system.restaurar)`, esconder/resetar em MENU/fim via `_reset_corrida()` — research.md R9/R10, contracts/fuel_can_lifecycle.md (depends: T030, T044)

**Checkpoint**: US6 funcional — recuperação jogável de combustível em prova

---

## Phase 9: User Story 7 - Variar a disponibilidade de galões pela dificuldade (Priority: P2)

**Goal**: Geração orientada por distância com taxa por ambiente (planície > deserto > floresta > gelo), piso/teto do total por corrida, teto de ativos, espaçamentos, offsets e validação livre de NPCs

**Independent Test**: Rodar nos 4 ambientes e comparar frequência; conferir piso/teto, espaçamentos, offsets e ausência de galões sobre NPCs; pausa/fim sem novas gerações

### Tests for User Story 7 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T046 [P] [US7] Create tests/unit/fuel_can_generation_test.gd cobrindo o teste obrigatório F: ordem planície > deserto > floresta > gelo em número de nascimentos por distância; geração orientada por distância (não por temporizador puro); `fuel_can_max_active` respeitado em 100% dos quadros; `fuel_can_min_per_race`/`max_per_race` sobre o total (Clarificação); offsets do início/chegada; espaçamento entre galões; **0 galões sobre NPCs** (snapshot sintético) e espaço `fuel_can_npc_spacing` para interagir sem colidir; posição inválida ⇒ pendente reavaliada, nunca confirmada; fora de `PLAYING` ou com estrada parada ⇒ 0 nascimentos — depends: T041, T043

### Implementation for User Story 7

- [X] T047 [US7] Implement geração orientada por distância em src/items/fuel_can_manager.gd: `distancia_desde_ultima` integrada por `speed × track_units_to_km × delta`, `intervalo_efetivo = fuel_can_spawn_interval_distance / spawn_rate[ambiente]`, guarda de `scroll > 0`, leitura de `GameConfig.current_environment_id` no momento — research.md R7, FR-028/FR-029 (depends: T045)
- [X] T048 [US7] Implement validações de nascimento em src/items/fuel_can_manager.gd: `max_active`, offsets de início/chegada, `fuel_can_min_spacing` entre ativos, `fuel_can_npc_spacing` contra o snapshot do trânsito, posição X nos limites dirigíveis vigentes, candidato pendente reavaliado até nascer ou expirar — research.md R7, FR-030/SC-010 (depends: T047)
- [X] T049 [US7] Implement piso e teto por corrida em src/items/fuel_can_manager.gd: contador `gerados_na_corrida`, corte em `fuel_can_max_per_race` (reciclagem de não coletados continua valendo) e antecipação de spawn quando abaixo de `fuel_can_min_per_race` — Clarificação de limites, SC-010/SC-011 (depends: T048)

**Checkpoint**: US7 funcional — balanceamento de disponibilidade por dificuldade

---

## Phase 10: User Story 8 - Ajustar o balanceamento só pela configuração (Priority: P3)

**Goal**: Todos os parâmetros novos alteráveis somente pelo `GameConfig`, sem valores de balanceamento fixos na lógica

**Independent Test**: Alterar cada parâmetro apenas pela configuração e observar o efeito; nenhum teste anterior quebra; nenhum arquivo de lógica precisou mudar

### Tests for User Story 8 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T050 [P] [US8] Create tests/unit/game_config_008_test.gd cobrindo o teste obrigatório I (configuração): todos os parâmetros `track_*`, dimensionamento e `fuel_can_*` existem em `GameConfig` com os tipos esperados; mutar cada um produz efeito observável no sistema correspondente sem alteração de lógica; rótulos `ui_*` presentes e não vazios (SC-016/FR-041) (depends: T001)

### Implementation for User Story 8

- [X] T051 [US8] Audit e refatoração mínima: remover qualquer constante de balanceamento que tenha vazado para `src/track/`, `src/items/`, `src/ui/` ou `src/game/gameplay_manager.gd` (conversões derivadas de `KMH_TO_SPEED_UNIT` são permitidas documentadas — research.md R1); garantir que `fuel_can_spawn_rate` e limites lêm apenas do `GameConfig` — FR-039/SC-016 (depends: T049)

**Checkpoint**: Todas as 8 user stories funcionais e independentes

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Validação de ponta a ponta, regressão e calibração

- [X] T052 Run suíte completa (`GODOT_BIN=... bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit`) e corrigir até exit 101 — 46 suítes atuais + 9 novas, 0 regressão SPECs 001–007 (SC-013)
- [ ] T053 Validate quickstart.md passos manuais 1–12 (aceitação A–I em gameplay), incluindo: freeze real da pausa, precedência do esgotamento, coleta sem colisão, reciclagem na base e posição livre de NPCs
- [X] T054 [P] Review de conformidade: comentários e docs em pt-BR (§VI), nenhum literal de usuário na lógica (FR-041), hitboxes/dimensões dos veículos inalteradas (SC-014), asset `gasolina.png` 32×51 sem redesenho (SC-014)
- [ ] T055 Calibra sementes CALIBRAÇÃO em src/config/game_config.gd conforme quickstart §4: corrida de referência com sobra de 15%–35%, frequência percebida planície > deserto > floresta > gelo, piso ≥ 4 e teto ≤ 12 galões por corrida — revalidar suíte + passos manuais 3–8 (depends: T052, T053)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências — começa imediatamente
- **Foundational (Phase 2)**: Depende do Setup (T001) — **BLOQUEIA todas as user stories**
- **US1 (Phase 3)**: Depende de Foundational (T016); MVP
- **US2 (Phase 4)**: Depende de Foundational; integra reset com US1 (T025/T030)
- **US3 (Phase 5)**: Depende de US2 (marcador/geometry) + Foundational
- **US4 (Phase 6)**: Depende de Foundational + US3 (guarda de corrida encerrada)
- **US5 (Phase 7)**: Depende de Foundational (T007) — independente de US2–US4 em teste
- **US6 (Phase 8)**: Depende de Foundational (T008) + US2 (rolagem/orquestração) para wiring
- **US7 (Phase 9)**: Depende de US6 (gerenciador de galões)
- **US8 (Phase 10)**: Depende de todas as stories (auditoria final)
- **Polish (Phase 11)**: Depende das stories desejadas

### User Story Dependencies

- **US1 (P1)**: Após Foundational — sem dependência de outras stories (MVP)
- **US2 (P1)**: Após Foundational — integra com US1 para reset/orquestração
- **US3 (P1)**: Após US2 (usa marcador de chegada)
- **US4 (P1)**: Após Foundational (+ US3 p/ guarda de fim)
- **US5 (P1)**: Após Foundational — independente
- **US6 (P2)**: Após Foundational (+ wiring de orquestração da US1/US2)
- **US7 (P2)**: Após US6
- **US8 (P3)**: Após todas

### Within Each User Story

- Testes escritos PRIMEIRO e devem FALHAR antes da implementação
- Esqueletos/stubs → implementação → wiring no `GameplayManager` → cena
- Story completa antes da próxima prioridade

### Parallel Opportunities

- **Setup**: T002–T006 em paralelo (5 arquivos distintos)
- **Foundational**: T009–T015 em paralelo (7 arquivos distintos); T008 paralelo a T009–T015
- **US1**: T017–T018 (testes) em paralelo; T019–T021 sequenciais no mesmo arquivo da UI
- **US2**: T026–T027 (testes) em paralelo
- **US6/US7**: T041 e T042 em paralelo; T046 após T043
- Histórias distintas podem ser trabalhadas em paralelo por agentes diferentes após Foundational (US5 ∥ US1, por exemplo)

---

## Parallel Example: User Story 2

```bash
# Lançar os dois testes da US2 juntos:
Task: "Create tests/unit/track_progression_test.gd"
Task: "Create tests/unit/track_finish_test.gd"

# Depois, implementação em paralelo quando os arquivos são distintos:
Task: "Implement núcleo de src/track/track_manager.gd"
Task: "Implement src/track/track_markers.gd"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL — bloqueia tudo)
3. Completar Phase 3: US1
4. **PARAR e VALIDAR**: menu → largada → pausa → reinício/menu funcionando
5. Demo/commit

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → teste independente → **MVP** (ciclo de sessão completo)
3. US2 → pista finita com indicador e marcações
4. US3 → vitória real
5. US4 → Game Over real (regra central completa)
6. US5 → balanceamento de combustível pela distância
7. US6 → galões coletáveis (recuperação)
8. US7 → balanceamento de disponibilidade
9. US8 → auditoria de configuração
10. Polish → regressão total, aceitação manual e calibração

### Parallel Team Strategy

Com múltiplos agentes:

1. Setup + Foundational juntos
2. Após Foundational:
   - Agente A: US1 → US2 → US3 (cadeia da pista)
   - Agente B: US5 (dimensionamento) → US4 (Game Over)
   - Agente C: US6 → US7 (galões)
3. US8 + Polish integrados no fim

---

## Notes

- **[P]** = arquivos diferentes, sem dependências
- **[Story]** = rastreabilidade com as user stories da spec
- Cada user story é completável e testável independentemente
- Testes obrigatórios (A–I) escritos primeiro, devem falhar antes da implementação
- Commit após cada tarefa ou grupo lógico (convenção do projeto em pt-BR)
- Qualquer parâmetro de balanceamento novo vive no `GameConfig` (nunca na lógica)

---

## Phase 12: Convergence

- [X] T056 Devolver todos os galões ativos ao pool (`items_layer.reset()`) quando a corrida termina em `VICTORY` ou `GAME_OVER` em src/game/gameplay_manager.gd (em `_avaliar_transicoes` ou nos handlers de fim), e criar teste de regressão cobrindo 0 galões após qualquer encerramento em tests/unit/race_reset_test.gd per FR-031, SC-011 (missing)

---

## Phase 13: Ajustes pós-implementação (aceite manual, 2026-10-11)

**Purpose**: Dois ajustes de experiência identificados no teste manual do usuário após a implementação completa; validados na suíte completa (50 suítes, 324 casos, exit 101) sem regressão.

- [X] T057 [US1] Destaque da opção ativa no menu em src/ui/ui_manager.gd: retângulo semitransparente (`ColorRect` branco ~18%) atrás da opção selecionada — "Selecionar veículo" + nome (opção 0) ou "Iniciar corrida" (opção 1); navegação `ui_up`/`ui_down` com `_opcao_menu`, `ui_accept` emite `start_race` apenas com a opção "Iniciar corrida" destacada; destaque reaplicado a cada troca e ao (re)entrar em MENU — contracts/ui_commands.md §3
- [X] T058 [US2] Banda `INÍCIO`/`CHEGADA` apresentada imediatamente ao iniciar em src/game/gameplay_manager.gd: `_show_ready()` cria os marcadores na entrada em `READY` (antes só nasciam após o timer de 1 s, na virada `READY → PLAYING` via `_reset_corrida`, que continua recriando-os — idempotente) — contracts/game_state_transitions.md §3
