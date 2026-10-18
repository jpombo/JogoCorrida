# Tasks: Sistema de Colisão entre NPCs

**Input**: Design documents from `/specs/006-npc-collision-system/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Incluídos — a constituição torna MUST a cobertura automatizada de lógica determinística de spawn/selecionar/posicionar e de restrições de limite da pista (§Testes), o spec mede tudo por SCs e o `quickstart.md` nomeia 9 suítes novas. Cada história lista suas suítes antes da implementação.

**Organization**: Tarefas agrupadas por user story (US1–US9) para permitir implementação e validação independentes. Ordem das fases segue a prioridade do spec: P1 (US1, US2, US3, US4, US5, US9) e depois P2 (US6, US7, US8).

## Format: `- [ ] [TaskID] [P?] [Story?] Description`

---

## Phase 1: Setup

**Purpose**: Parâmetros de configuração do novo sistema, sem lógica

- [X] T001 Add SPEC-006 parameter block to `src/config/game_config.gd`: `npc_collision_cooldown`, `npc_drift_force_min/max`, `npc_drift_duration_min/max`, `npc_drift_recovery_rate`, `npc_relative_position_threshold`, `npc_border_margin`, `npc_max_chain_depth`, `npc_chain_timeout`, `npc_displacement_limit`, `npc_spawn_safety_distance`, `npc_collision_prediction_horizon`, `npc_min_relative_speed`, `npc_active_area_margin`, `npc_reevaluation_interval`, `npc_player_speed_change_threshold` — **sem novo valor para `npc_max_active`**: o teto é projeção do existente no SPEC-004 (`traffic_max_visible_by_difficulty`), fonte única (FR-042/FR-044, data-model §6, research §Valores de configuração)

**Checkpoint**: GameConfig compilando com o bloco `npc_*`; cena principal abrindo sem custo adicional.

---

## Phase 2: Foundational (Blocking Prerequisites)

Pré-requisitos que bloqueiam todas as histórias: payload do evento, estrutura de estado por veículo, esqueleto do sistema, hooks aditivos inertes e wiring.

- [X] T002 Create `NpcCollisionData` resource in `src/collision/npc_collision_data.gd` com os 7 campos do contrato (`causador`, `atingido`, `tipo` enum LONGITUDINAL/LATERAL, `intensidade`, `direcao_drift`, `cadeia_id`, `profundidade`) per `contracts/npc_collision_event.md`
- [X] T003 Create `NpcDriftState` skeleton in `src/collision/npc_drift_state.gd`: enum de fases NORMAL/IMPACTO/DRIFT/RECUPERACAO, campos do data-model §4, método `iniciar` com substituição (Clarificação Q4), sem lógica de borda ainda (FR-021)
- [X] T004 [P] Add additive NPC drift hooks to `src/traffic/traffic_vehicle.gd`: campo `npc_drift: NpcDriftState` (requer T003), `aplicar_drift_npc(direcao, forca, duracao)` (substitui drift em curso) e `atualizar_drift_npc(delta, limite_esq, limite_dir)` — escreve SOMENTE em `position.x`, velocidade intocada, inerte sem chamada (FR-014, FR-017, contracts/consumed_apis.md §1)
- [X] T005 Create `NpcCollisionSystem` skeleton in `src/collision/npc_collision_system.gd`: sinal `npc_collision_occurred(data: NpcCollisionData)`, método `update(delta, npcs, bounds_for_y)` consumindo `active_vehicles` + `Callable(road, "get_boundaries_for_player_y")`, ainda sem consequências (contracts/consumed_apis.md)
- [X] T006 [P] Wire `NpcCollisionSystem` in `src/game/gameplay_manager.gd`: instanciar o sistema e chamar `update` **depois** de `traffic_layer.update()` e **antes** de `collision_system.update()`, na hierarquia de atualização existente (research R9)
- [X] T007 Implement pair candidate enumeration in `src/collision/npc_collision_system.gd`: pares canônicos sobre os ativos com chave `min(instance_id):max(instance_id)`, ordenação determinística `(y, instance_id)` e cache de pares reutilizado (data-model §1, research R5/R9); **latch de sobreposição por par**: aplica consequência UMA única vez por episódio de contato (rearmado na separação), evitando reiniciar o drift a cada quadro antes do cooldown completo de T032 (FR-026, data-model §5)

**Checkpoint**: Sistema registrado por quadro e inerte; hooks aditivos sem efeito; suítes anteriores verdes (SC-016 baseline).

---

## Phase 3: User Story 1 - Alcançar um NPC mais lento e desviá-lo (P1) 🎯 MVP

**Goal**: Detectar o contato longitudinal entre dois NPCs na mesma trajetória, classificar causador/atingido e aplicar drift lateral no atingido; causador intacto e velocidade de todos inalterada.

**Independent Test**: Dois NPCs na mesma trajetória (esporte atrás de caminhão) ao alcance curto → contato detectado, classificação "longitudinal", drift no caminhão para o lado oposto ao impacto, esporte sem drift e sem mudança de velocidade (US1-CA1–CA5, SC-004, SC-014).

### Tests (escrever e ver falhar antes da implementação)

- [X] T008 [P] [US1] Detection suite in `tests/unit/npc_collision_detection_test.gd`: interseção → colisão classificada LONGITUDINAL com drift só no atingido; sem interseção, nenhuma colisão (SC-004, FR-010/FR-011)
- [X] T009 [P] [US1] Drift suite in `tests/unit/npc_collision_drift_test.gd`: direção oposta ao impacto pelos dois lados; decisão determinística dentro da margem neutra; `get_speed()` idêntico antes/durante/depois (SC-005, SC-014)

### Implementation

- [X] T010 [US1] Implement hitbox intersection for NPC pairs in `src/collision/npc_collision_system.gd`: `Rect2` por categoria a partir de `GameConfig.NPC_HITBOX_SIZES` com fallback em `get_occupied_area()`, sem alocação por quadro (FR-010, contracts/consumed_apis.md §1)
- [X] T011 [US1] Implement impact classification in `src/collision/npc_collision_system.gd`: menor penetração nos eixos → LONGITUDINAL/LATERAL; em longitudinal, quem alcança é o causador (FR-011, FR-013, research R2)
- [X] T012 [US1] Implement intensity computation in `src/collision/npc_collision_system.gd`: `|v_a − v_b| / collision_intensity_divisor`, clamp [0,1] (FR-012, mesma convenção da SPEC-005)
- [X] T013 [US1] Implement drift direction in `src/collision/npc_collision_system.gd`: lado oposto ao impacto com `npc_relative_position_threshold`; empate absoluto resolvido de forma estável (FR-015, research R2)
- [X] T014 [US1] Apply collision consequences in `src/collision/npc_collision_system.gd` + `src/collision/npc_drift_state.gd`: drift no atingido via `aplicar_drift_npc` (substituição em novo impacto), causador sem drift, **nenhum caminho de escrita em velocidade** (FR-014, FR-016, FR-017, research R10)

**Checkpoint**: US1 validável de forma independente — T008/T009 verdes (contato avalia os primeiros quadros da sobreposição; o latch de T007 garante aplicação única) e cenário manual US1 do `quickstart.md` passando. O cooldown com tempo completo entra em T032 (US5).

---

## Phase 4: User Story 2 - Prever a colisão antes do descarte (P1)

**Goal**: Avaliar continuamente os pares na mesma trajetória e prever colisão somente quando o encontro cabe na janela de atividade conjunta — sem falsos positivos nem falsos negativos.

**Independent Test**: Cenário 1 (esporte atrás de caminhão, distância curta) → 100% de previsão; Cenário 2 (distância tão grande que o encontro seria pós-descarte) → 0; mesma velocidade → 0; trajetórias distintas → 0 (US2-CA1–CA5, SC-001–SC-003).

### Tests

- [X] T015 [P] [US2] Prediction suite in `tests/unit/npc_prediction_test.gd`: Cenário 1 × Cenário 2, par de mesma velocidade, par em trajetórias distintas e par com encontro dentro da janela (SC-001–SC-003, FR-002–FR-006)

### Implementation

- [X] T016 [US2] Implement trajectory overlap check in `src/collision/npc_collision_system.gd`: projeções laterais das hitboxes; sem sobreposição → sem previsão e sem colisão (FR-006)
- [X] T017 [US2] Implement activity window calculation in `src/collision/npc_collision_system.gd`: `ttc = distância / (v_traseiro − v_dianteiro)` acima de `npc_min_relative_speed`, comparado à janela (menor tempo até descarte dos dois + `npc_active_area_margin`, cap `npc_collision_prediction_horizon`, velocidades e estado da pista correntes) (FR-002–FR-005, research R1)
- [X] T018 [US2] Store pair verdicts in `src/collision/npc_collision_system.gd`: veredito `potencial` por par canônico no cache, avaliação sob demanda e periódica (não todos os pares por quadro) (FR-007, FR-008)
- [X] T019 [US2] Exclude the player from NPC pair evaluation in `src/collision/npc_collision_system.gd`: presença do jogador entre dois NPCs não bloqueia nem altera a avaliação (FR-009)

**Checkpoint**: Previsão correta nos 4 cenários do SC-001–SC-003 com o sistema ainda sem efeitos colaterais novos.

---

## Phase 5: User Story 3 - Sofrer contato lateral com outro NPC (P1)

**Goal**: Classificar contatos laterais, identificar o causador (quem fecha a trajetória) e escalar a resposta lateral pela intensidade do impacto.

**Independent Test**: Dois NPCs lado a lado a mesma altura → classificação "lateral", atingido desloca para o lado do impacto, causador intacto; intensidades maiores produzem deslocamentos maiores dentro dos intervalos configurados (US3-CA1–CA4, SC-004, SC-005).

### Tests

- [X] T020 [P] [US3] Lateral cases em `tests/unit/npc_collision_detection_test.gd`: dominância horizontal → LATERAL; direção do atingido pelo lado do impacto; estabilidade dentro da margem neutra; intensidade proporcional (US3-CA1–CA4)

### Implementation

- [X] T021 [US3] Identify lateral causador in `src/collision/npc_collision_system.gd`: quem invadiu/fechou a coluna do vizinho é o causador; empates resolvidos de forma determinística e estável (FR-013)
- [X] T022 [US3] Scale lateral drift by intensity in `src/collision/npc_collision_system.gd`: força e duração interpoladas entre `npc_drift_force/duration_min/max` pela intensidade, aplicadas ao atingido apenas (FR-014)

**Checkpoint**: US1 e US3 cobrem os dois tipos de colisão com a mesma pipeline de consequências.

---

## Phase 6: User Story 4 - Nenhum NPC sai da pista durante um impacto (P1)

**Goal**: Manter o invariante "nenhum veículo ultrapassa os limites válidos" em qualquer impacto, incluindo bordas em pista estreita e transições de largura.

**Independent Test**: Atingido colado na borda direita de 2 vias com drift normal "direita" → drift inverte para a esquerda; sem espaço em nenhum lado → deslocamento vai ao causador; partida contínua nas transições 2→4→2 com 0 veículos fora da área trafegável (US4-CA1–CA5, SC-006, SC-007, SC-018).

### Tests

- [X] T023 [P] [US4] Bounds suite in `tests/unit/npc_collision_bounds_test.gd`: inversão na borda; transferência ao causador quando sem espaço; 0 ultrapassagens por quadro; limites vigentes durante a transição 2↔4 vias (SC-006, SC-007, SC-018)

### Implementation

- [X] T024 [US4] Query per-vehicle bounds every frame in `src/collision/npc_collision_system.gd`: `bounds_for_y` chamado na **altura de cada envolvido** a cada quadro, sem largura memorizada (FR-018, FR-040, research R3)
- [X] T025 [US4] Implement border fallback in `src/collision/npc_collision_system.gd`: atingido dentro de `npc_border_margin` da borda → tenta direção normal, senão lado oposto, senão **transfere o deslocamento ao causador** (também clampado) (FR-019, research R3)
- [X] T026 [US4] Enforce displacement limit in `src/collision/npc_drift_state.gd`: deslocamento acumulado ≤ `npc_displacement_limit` e clamp continuo pelos limites da pista durante DRIFT e RECUPERACAO (FR-020, FR-022)

**Checkpoint**: SC-006/SC-007 verdes nos testes de borda; transição de vias sem saídas.

---

## Phase 7: User Story 5 - Efeito dominó controlado, sem loops nem impactos repetidos (P1)

**Goal**: Encadear impactos via deslocamento do atingido com profundidade/expiração/registro de processados, e isolar bloqueios por par de veículos.

**Independent Test**: Três NPCs em fila → cadeia A→B→C (profundidade 2); quarto elo além do máximo não processa; A↔B em cooldown com B↔C livre; dois processamentos do mesmo veículo na mesma cadeia → 0; cadeias paralelas com ids próprios (US5-CA1–CA8, SC-008, SC-009).

### Tests

- [X] T027 [P] [US5] Chain suite in `tests/unit/npc_collision_chain_test.gd`: A→B→C, profundidade máxima, 0 veículos repetidos na cadeia, expiração por tempo, cadeias paralelas com `cadeia_id`/profundidade próprios (SC-008, FR-024/FR-025)
- [X] T028 [P] [US5] Cooldown suite in `tests/unit/npc_collision_cooldown_test.gd`: A↔B sem eventos durante a janela enquanto B↔C colide; rearmento somente após separação; par separando e reencostando durante o cooldown → 0 eventos (SC-009, FR-026/FR-027)

### Implementation

- [X] T029 [US5] Create `NpcChainState` in `src/collision/npc_chain_state.gd`: `id` monotônico, `profundidade_atual/máxima`, `tempo_restante` (`npc_chain_timeout`) e conjunto `processados` (data-model §3)
- [X] T030 [US5] Implement chain inheritance in `src/collision/npc_collision_system.gd`: um impacto herda cadeia **apenas** quando o atingido, com drift ainda ativo, atinge um terceiro; colisões sem esse elo iniciam cadeia própria (FR-024, Clarificação Q5)
- [X] T031 [US5] Enforce chain controls in `src/collision/npc_collision_system.gd`: bloqueio em `npc_max_chain_depth`, descarte ao expirar, veículo processado 1× por cadeia (0 loops) (FR-025)
- [X] T032 [US5] Implement per-pair cooldown in `src/collision/npc_collision_system.gd`: chave canônica do par, countdown por quadro, rearmento após expiração **e** separação; supressão total de evento e consequência (FR-026, FR-027, research R5)

**Checkpoint**: US5 validável sem US6–US8 — cadeia, profundidade e isolamento por par nos testes.

---

## Phase 8: User Story 9 - Preservar o jogo todo: jogador, 5 NPCs e transições (P1)

**Goal**: Integrar sem duplicação: NPC deslocado que toca o jogador → exatamente 1 evento da SPEC-005; teto de 5 NPCs; zero regressão das SPECs 001–005.

**Independent Test**: Partida em Gelo com 5 NPCs, transição completa 2→4→2 e ao menos uma colisão NPC×NPC que termina em contato com o jogador → 1 evento SPEC-005, limites respeitados e todas as suítes anteriores verdes (US9-CA1–CA6, SC-011, SC-015, SC-016, SC-018).

### Tests

- [X] T033 [P] [US9] Regression suite in `tests/unit/npc_collision_regression_test.gd`: NPC deslocado que toca o jogador → exatamente 1 evento `CollisionSystem.collision_occurred` e 0 eventos NPC×NPC; até 5 ativos com pares avaliados; **asserções FR-043**: `rotation == 0` em todos os veículos, nenhuma velocidade de NPC alterada e nenhuma frenagem/desvio estratégico observado após colisões (SC-011, SC-015, FR-043)
- [X] T034 [US9] Run full headless suite via `addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit` e confirmar exit 101 — 24 suítes SPEC-001–005 sem regressão (SC-016)

### Implementation

- [X] T035 [US9] Verify wiring order in `src/game/gameplay_manager.gd`: `npc_collision_system.update` antes de `collision_system.update` para que o contato do NPC deslocado seja visto no mesmo quadro (research R9, FR-038)
- [X] T036 [US9] Resolve the active ceiling as a read-only projection in `src/collision/npc_collision_system.gd`: `npc_max_active` **derivado** do teto por dificuldade do SPEC-004 (`GameConfig.traffic_max_visible_by_difficulty`/`traffic_max_vehicles`) — sem valor armazenado novo; avaliação correta com até 5 ativos, configurável pela fonte existente (FR-042)
- [X] T037 [US9] Manual acceptance em `quickstart.md` Validação 2.9: Gelo com 5 NPCs + transição de vias + colisão NPC×NPC → contato com o jogador (SC-011, SC-018, SC-019) — executado em 2026-10-16 sem problemas, ver Phase 13

**Checkpoint**: Todo o P1 entregue e o jogo preservado — suíte completa verde.

---

## Phase 9: User Story 6 - Recuperação gradual e evento para outros sistemas (P2)

**Goal**: Completar a máquina de estados do NPC (temporariedade, recuperação, permanência final) e emitir o evento informativo de 7 campos.

**Independent Test**: Colisão aplicada → fases normal→colisão→drift→recuperação→normal sem outros estados, velocidade sempre idêntica, NPC permanece onde o drift terminou; assinar o sinal e receber exatamente 1 evento com os 7 campos (US6-CA1–CA6, FR-021, FR-041).

### Tests

- [X] T038 [P] [US6] Event suite in `tests/unit/npc_collision_event_test.gd`: exatamente 1 evento por colisão válida com os 7 campos; 0 eventos sob cooldown e sob bloqueio de cadeia; sem ouvintes → nada muda (FR-041, contracts/npc_collision_event.md)

### Implementation

- [X] T039 [US6] Complete NPC state sequence in `src/collision/npc_drift_state.gd`: normal→colisão→drift→recuperação→normal, sem outros estados; recuperação à taxa `npc_drift_recovery_rate`; duração limitada (FR-021, FR-023)
- [X] T040 [US6] Keep the reached lateral position in `src/collision/npc_drift_state.gd`: encerrada a recuperação, sem retorno à faixa de origem — só os limites da pista e a trajetória atual valem (FR-022, Clarificação Q1)
- [X] T041 [US6] Emit the collision event in `src/collision/npc_collision_system.gd`: `npc_collision_occurred.emit(data)` exatamente 1× por colisão válida, preenchendo os 7 campos após a classificação (FR-041)

**Checkpoint**: US6 independente — estado completo e evento observável por um ouvinte de teste.

---

## Phase 10: User Story 7 - Não nascer em cima de um conflito (P2)

**Goal**: Validar cada nascimento contra a janela de atividade e, sem opção no quadro, adiar o nascimento para o seguinte sem perdê-lo.

**Independent Test**: Nascimento rápido atrás de lento na mesma faixa → reposiciona/outra faixa/adia ao quadro seguinte (nunca descartado até o próximo intervalo); conflito pós-descarte → aceito; nenhum NPC nasce sobreposto (US7-CA1–CA5, SC-010).

### Tests

- [X] T042 [P] [US7] Spawn suite in `tests/unit/npc_collision_spawn_test.gd`: 0 nascimentos sobrepostos; conflito dentro da janela identificado; encontro pós-descarte aceito; adiamento ao quadro seguinte com revalidação e sem perda (SC-010, FR-028–FR-031)

### Implementation

- [X] T043 [US7] Implement `validar_spawn` in `src/collision/npc_collision_system.gd`: sobreposição imediata, `npc_spawn_safety_distance`, futuro pela janela (R1) e veredito `{aceito, x, y, adiar}` per `contracts/spawn_validation.md` (FR-028, FR-030, FR-031)
- [X] T044 [US7] Add validation hook in `src/traffic/traffic_manager.gd` `_tentar_spawn`: após as validações existentes, consulta o validador; recusa → tenta outra posição e depois outra faixa (FR-028, contracts/spawn_validation.md)
- [X] T045 [US7] Implement next-frame deferral in `src/traffic/traffic_manager.gd`: candidato pendente revalidado a cada quadro com posições atualizadas; cronômetro de intervalo preservado; reposição abaixo de `traffic_min_visible` intacta (FR-029, Clarificação Q3)

**Checkpoint**: US7 validável com o trânsito real — densidade mínima do SPEC-004 sem regressão (FR-063).

---

## Phase 11: User Story 8 - Reavaliar quando o jogador muda de velocidade (P2)

**Goal**: Reavaliar as condições de colisão sob demanda, por eventos e por mudança relevante da velocidade do jogador — sem colisões artificiais.

**Independent Test**: Formação segura → jogador frea → nova aproximação passa a ser detectada; sem mudança relevante → nada muda; qualquer reavaliação sem janela satisfeita → 0 colisões (US8-CA1–CA6, SC-012, SC-013).

### Tests

- [X] T046 [P] [US8] Reevaluation cases em `tests/unit/npc_prediction_test.gd`: frear com 5 NPCs → reavaliação e nova condição detectada; velocidade mantida → sem mudanças; janela sempre satisfeita antes de qualquer registro (SC-012, SC-013)

### Implementation

- [X] T047 [US8] Monitor player speed in `src/collision/npc_collision_system.gd`: variação absoluta > `npc_player_speed_change_threshold` dispara reavaliação imediata dos pares (FR-032, FR-033)
- [X] T048 [US8] Implement periodic + event reevaluation in `src/collision/npc_collision_system.gd`: a cada `npc_reevaluation_interval` e nos eventos `vehicle_spawned`/`vehicle_recycled`, fim de drift, `segment_type_changed`/`boundary_changed` (FR-008, FR-033, research R8)
- [X] T049 [US8] Guarantee no artificial collisions in `src/collision/npc_collision_system.gd`: reavaliação só atualiza vereditos de pares; evento exige interseção real **e** regra da janela satisfeita no momento (FR-035)

**Checkpoint**: Todas as 9 histórias funcionais e independentes.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Validação ponta a ponta, configurabilidade e qualidade

- [X] T050 [P] Configurability check per `quickstart.md` Validação 3 (SC-017): alterar `npc_collision_cooldown`, `npc_drift_force_min/max`, `npc_max_chain_depth`, `npc_border_margin`, `npc_reevaluation_interval` etc. e confirmar efeito observável sem tocar código — executado em 2026-10-16 sem problemas, ver Phase 13
- [X] T051 [P] Endurance check per `quickstart.md` Validação 2.9: **3 rodadas de 10 minutos** (pista de 2 vias, de 4 vias e com a transição completa 2→4→2) com jogador + 5 NPCs — 0 veículos fora da área trafegável (SC-006/SC-018) e 60 FPS como meta sem queda recorrente abaixo de 30 (SC-019) — executado em 2026-10-16 sem problemas, ver Phase 13
- [X] T052 Run `quickstart.md` end-to-end (Validações 1–3) com a suíte headless verde (exit 101) e o aceite manual US1–US9 concluído — concluído em 2026-10-16 (suíte 63 suítes/388 casos, exit 101), ver Phase 13
- [X] T053 [P] Code quality pass em `src/collision/npc_*.gd`, `src/traffic/traffic_vehicle.gd`, `src/traffic/traffic_manager.gd`: comentários em pt-BR explicando o PORQUÊ, sem números mágicos (todos via `GameConfig`), responsabilidade única preservada (§Qualidade de Código, FR-044)
- [X] T054 Update `AGENTS.md` §Estado atual com a conclusão da SPEC-006 e o novo total de suítes/casos

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — começa imediatamente
- **Foundational (Phase 2)**: depende do Setup — **BLOQUEIA todas as user stories**
- **User Stories (Phases 3–11)**: todas dependem do Foundational
  - Ordem de prioridade do spec: US1 (P1, MVP) → US2 → US3 → US4 → US5 → US9 (P1) → US6 → US7 → US8 (P2)
- **Polish (Phase 12)**: depende das histórias desejadas (mínimo: US1 + US9 para validação parcial; completo: todas)

### User Story Dependencies

- **US1 (P1)**: começa após Foundational — sem dependências de outras histórias
- **US2 (P1)**: após Foundational; usa o cache de pares do T007 (Foundational, não de US1)
- **US3 (P1)**: após Foundational; reutiliza a classificação da US1 (T011) — se implementadas em paralelo, US3 completa os casos laterais sobre a mesma função
- **US4 (P1)**: após US1 (só há deslocamento para limitar com o drift existente)
- **US5 (P1)**: após US1 (precisa de contato/resultado de colisão); cadeia usa o drift da US1
- **US9 (P1)**: integra US1–US5 — executar depois delas
- **US6 (P2)**: após US1 (fases e evento completam o que a US1 iniciou)
- **US7 (P2)**: após US2 (usa a regra da janela/R1) — independente de US3–US6
- **US8 (P2)**: após US2 (reavalia o veredito de previsão)

### Within Each User Story

- Testes escritos e falhando antes da implementação
- Esqueleto/entidades → lógica pura → integração nos hooks → wiring
- História completa e verde antes da próxima prioridade

### Parallel Opportunities

- Setup: T001 é único
- Foundational: T004 (após T003) e T006 são `[P]` (arquivos distintos)
- US1: T008 + T009 em paralelo; US2: T015 isolado; US3: T020; US4: T023; US5: T027 + T028; US9: T033; US6: T038; US7: T042; US8: T046
- Entre histórias com fases distintas (ex.: US7 e US8, ambas P2) — arquivos compartilhados são só `npc_collision_system.gd` e `traffic_manager.gd`; coordenar ou executar sequencialmente
- Polish: T050 + T051 + T053 `[P]`

---

## Parallel Example: User Story 1

```bash
# Lançar juntas as duas suítes da US1 (arquivos distintos):
Task: "Detection suite in tests/unit/npc_collision_detection_test.gd"
Task: "Drift suite in tests/unit/npc_collision_drift_test.gd"

# Depois a implementação (mesmo arquivo src/collision/npc_collision_system.gd — sequencial):
Task: "Implement hitbox intersection for NPC pairs"
Task: "Implement impact classification"
Task: "Implement intensity computation"
Task: "Implement drift direction"
Task: "Apply collision consequences"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (T001)
2. Completar Phase 2: Foundational (**CRÍTICO** — bloqueia todas as histórias)
3. Completar Phase 3: User Story 1
4. **PARAR e VALIDAR**: T008/T009 verdes + cenário manual US1
5. Suíte completa em verde = entrega arcade mínima viável (colisão longitudinal + drift)

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → testar → demo (MVP)
3. US2 → previsão auditável → demo
4. US3 → tipo lateral → demo
5. US4 → invariante de pista → demo
6. US5 → dominó controlado → demo
7. US9 → integração/regressão → pacote P1 fechado
8. US6 → estados/evento → US7 → spawn → US8 → reavaliação → P2 fechado
9. Polish → quickstart completo

### Parallel Team Strategy

1. Equipe completa Setup + Foundational juntos
2. Depois do Foundational: Dev A: US1 → US4/US5; Dev B: US2 → US7/US8; Dev C: US3/US6
3. US9 (integração) espera as histórias P1

---

## Notes

- `[P]` = arquivos distintos, sem dependência de tarefas incompletas
- `[Story]` (US1–US9) mapeia a tarefa à história do spec para rastreabilidade
- Cada história é completável e validável de forma independente (teste próprio no cabeçalho da fase)
- Verificar que os testes falham antes de implementar
- Commit após cada tarefa ou grupo lógico
- Parar em qualquer checkpoint para validar a história isoladamente
- Evitar: tarefas vagas, conflitos no mesmo arquivo, dependências que quebram a independência das histórias

---

## Phase 13: Aceite manual (2026-10-16)

**Purpose**: Execução das validações manuais do `quickstart.md` (2.9 e 3) e do end-to-end (Validações 1–3) pelo usuário, no build que já inclui as SPEC-007/008/009; registro exigido por T037/T050–T052.

- [X] T037 Validação 2.9 — **sem problemas identificados**: Gelo com 5 NPCs junto ao jogador, transição de vias 2↔4 e colisão NPC×NPC com contato/resultados junto ao jogador, sem veículo fora da área trafegável (SC-011, SC-018, SC-019).
- [X] T050 Validação 3 (configurabilidade) — **sem problemas identificados**: alterações em `npc_collision_cooldown`, `npc_drift_force_min/max`, `npc_max_chain_depth`, `npc_border_margin`, `npc_reevaluation_interval` etc. produzem efeito observável sem tocar código (SC-017).
- [X] T051 Endurance — **sem problemas identificados**: 3 rodadas de 10 minutos (2 vias, 4 vias e transição completa 2→4→2) com jogador + 5 NPCs, 0 veículos fora da área trafegável e frame rate estável (SC-006/SC-018/SC-019).
- [X] T052 Quickstart end-to-end (Validações 1–3) — concluído com a suíte headless verde na mesma data (**63 suítes, 388 casos, exit 101**) e o aceite manual US1–US9 fechado.
- **Pendência que permanece (não é aceite manual)**: implementação do **FR-046** do clarify de 2026-10-09 (cedência do espaçamento mínimo durante o movimento entre velocidades distintas) e a consistência spec↔plan↔tasks dele decorrente — registrada em `AGENTS.md` §Estado atual.
