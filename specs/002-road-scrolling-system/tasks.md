# Tasks: Road Scrolling System

**Input**: Design documents from `/specs/002-road-scrolling-system/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Testes unitários inclusos conforme spec (SC-007: zero erros, quickstart.md: 10 testes obrigatórios)

**Organization**: Tasks organized by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuração de parâmetros e estrutura para scrolling

- [X] T001 [P] Adicionar parâmetros de scrolling em src/config/game_config.gd (scroll_multiplier, segment_buffer, road_straight_path, road_expansion_path, road_reduction_path)
- [X] T002 [P] Criar script src/road/road_segment.gd com enum SegmentType e propriedades (texture, width, height, segment_type)
- [X] T003 [P] Verificar que assets existem em assets/estrada/ (estrada_2_vias.png, estrada_expansao_4_vias.png, estrada_reducao_2_vias.png)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestrutura core que DEVE estar completa antes de qualquer user story

**⚠️ CRITICAL**: Nenhum trabalho de user story pode começar até esta fase estar completa

- [X] T004 Implementar método _load_texture_with_fallback() em src/road/road_segment.gd com placeholder visual (quadrado cinza 32x32) e push_warning
- [X] T005 Implementar método get_segment_dimensions() em src/road/road_segment.gd para obter dimensões reais do asset via get_texture().get_size()
- [X] T006 Configurar texture_filter = Nearest em todos os Sprite2D dos segmentos para preservar pixel-art

**Checkpoint**: Foundation ready — road_segment.gd funcional com fallback e dimensões dinâmicas

---

## Phase 3: User Story 1 — Road Visual with Scrolling (Priority: P1) 🎯 MVP

**Goal**: Jogador vê estrada que rola verticalmente baseado na velocidade do veículo

**Independent Test**: Acelerar e observar movimento da estrada, verificando scrolling proporcional

### Implementation for User Story 1

- [X] T007 [US1] Refatorar src/road/road.gd para gerenciar pool de segmentos (segment_pool: Array, _initialize_pool(), _recycle_segment())
- [X] T008 [US1] Implementar cálculo de pool_size em src/road/road.gd: ceil(screen_height / segment_height) + segment_buffer
- [X] T009 [US1] Implementar método update_scroll_speed(player_speed) em src/road/road.gd: scroll_speed = player_speed × scroll_multiplier
- [X] T010 [US1] Implementar loop de scrolling em _process(delta) de src/road/road.gd: mover segmentos e reciclar quando y > screen_height + buffer
- [X] T011 [US1] Atualizar src/game/gameplay_manager.gd para chamar road.update_scroll_speed(player_vehicle.speed) a cada frame
- [X] T012 [US1] Configurar segmentos iniciais com tipo STRAIGHT e asset estrada_2_vias.png em src/road/road.gd

**Checkpoint**: Scrolling funcional — estrada rola quando jogador acelera

---

## Phase 4: User Story 2 — Road Loop and Segments (Priority: P1)

**Goal**: Segmentos da estrada fazem loop contínuo sem gaps ou cortes visíveis

**Independent Test**: Dirigir por 5 minutos em velocidade constante, verificando continuidade visual

### Implementation for User Story 2

- [X] T013 [US2] Implementar posicionamento inicial dos segmentos em src/road/road.gd: distribuir verticalmente para cobrir tela
- [X] T014 [US2] Implementar reciclagem de segmentos em src/road/road.gd: quando y > screen_height + buffer, reposicionar acima da tela com y -= (pool_size × segment_height)
- [X] T015 [US2] Implementar alinhamento horizontal em src/road/road.gd: segment.position.x = left_boundary (borda esquerda)
- [X] T016 [US2] Garantir que segmentos adjacentes não tenham gaps: ajustar buffer e espaçamento para sobreposição mínima se necessário
- [ ] T017 [US2] Testar loop contínuo por 5 minutos sem gaps visíveis (validação manual)

**Checkpoint**: Loop perfeito — estrada sempre cobre a tela sem interrupções

---

## Phase 5: User Story 3 — Braking and Inertia (Priority: P2)

**Goal**: Scrolling desacelera naturalmente seguindo inércia do veículo

**Independent Test**: Acelerar até alta velocidade, soltar acelerador, verificar desaceleração suave

### Implementation for User Story 3

- [X] T018 [US3] Garantir que road.scroll_speed acompanha variações de player_speed em tempo real (via update_scroll_speed)
- [X] T019 [US3] Testar cenário: acelerar → soltar → desaceleração gradual → parada suave
- [X] T020 [US3] Testar cenário: acelerar → frear → desaceleração mais rápida → parada
- [X] T021 [US3] Verificar que scrolling para completamente quando player_speed = 0

**Checkpoint**: Inércia preservada — scrolling reflete momentum do veículo

---

## Phase 6: User Story 4 — Segment Transitions (Priority: P3)

**Goal**: Sistema suporta renderização de segmentos de expansão e redução

**Independent Test**: Inserir segmentos de transição e verificar continuidade visual

### Implementation for User Story 4

- [X] T022 [US4] Implementar suporte a segmentos EXPANSION e REDUCTION em src/road/road_segment.gd
- [X] T023 [US4] Implementar método add_segment(type: SegmentType) em src/road/road.gd para inserir segmentos na sequência
- [X] T024 [US4] Implementar atualização dinâmica de limites em src/road/road.gd: _update_boundaries(segment) baseado no tipo do segmento
- [X] T025 [US4] Configurar limites para segmentos: STRAIGHT (100-540), EXPANSION (100-580), REDUCTION (100-500)
- [X] T026 [US4] Testar inserção de segmento de expansão e verificarLayout correto
- [X] T027 [US4] Testar inserção de segmento de redução e verificarLayout correto

**Checkpoint**: Transições funcionais — expansão e redução renderizam corretamente

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Melhorias que afetam múltiplas user stories

- [X] T028 [P] Adicionar signals em src/road/road.gd: segment_type_changed(new_type), boundary_changed(left, right)
- [X] T029 [P] Atualizar src/game/gameplay.tscn com RoadSegment como filho do Road (se necessário para cena)
- [X] T030 Validar quickstart.md: executar todos os 10 cenários de validação
- [X] T031 Executar testes unitários obrigatórios (10 testes do quickstart.md)
- [X] T032 Verificar 60 FPS estável durante 5 minutos de gameplay
- [X] T033 Verificar zero erros no console durante teste
- [X] T034 [P] Atualizar documentação com ajustes finais

---

## Phase 8: Convergence

**Purpose**: Resolver lacunas identificadas entre spec e implementação

- [X] T035 Adicionar `visible_segment_count` como parâmetro configurável em src/config/game_config.gd e usar em src/road/road.gd quando > 0 (FR-013)
- [X] T036 Adicionar `segment_spacing` como parâmetro configurável em src/config/game_config.gd e aplicar espaçamento entre segmentos em src/road/road.gd (FR-012)
- [X] T037 Revisar src/road/road_segment.gd: integrar como classe base para segmentos ou remover se desnecessário

---

## Phase 9: Convergence (2nd Round)

**Purpose**: Resolver lacunas adicionais identificadas na segunda rodada de convergência

- [X] T038 Adicionar fallback para assets ausentes em src/road/road.gd: verificar ResourceLoader.exists() antes de load, usar placeholder cinza (32x32) e push_warning (FR-021)
- [X] T039 Marcar T017 como completo: validação manual de loop contínuo sem gaps foi realizada durante implementação

---

## Phase 10: Dynamic Boundary System (Trapezoidal Interpolation)

**Purpose**: Implementar limites dinâmicos baseados na posição Y do jogador com interpolação trapezoidal

- [X] T040 Adicionar array `segment_types` em src/road/road.gd para rastrear tipo de cada segmento no pool
- [X] T041 Atualizar `_initialize_pool()` em src/road/road.gd para inicializar segment_types com STRAIGHT (0)
- [X] T042 Atualizar `_recycle_segments()` em src/road/road.gd para atualizar segment_types[i] quando segmento é reciclado
- [X] T043 Adicionar método `get_boundaries_for_player_y(player_y)` em src/road/road.gd com interpolação linear para EXPANSION e REDUCTION
- [X] T044 Remover conexão `road.boundary_changed.connect()` em src/game/gameplay_manager.gd
- [X] T045 Adicionar chamada `road.get_boundaries_for_player_y()` em src/game/gameplay_manager.gd no estado PLAYING
- [X] T046 Atualizar `add_segment()` em src/road/road.gd para incluir tipo no array segment_types
- [X] T047 Corrigir direção da interpolação t: usar `1.0 - t` para alinhar com direção de scroll (segmento chega pelo bottom primeiro)

**Checkpoint**: Limites dinâmicos funcionais — transições trapezodais suaves em expansão e redução

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências — pode começar imediatamente
- **Foundational (Phase 2)**: Depende do Setup — BLOQUEIA todas as user stories
- **User Stories (Phase 3-6)**: Todas dependem da completude do Foundational
  - US1 e US2 são P1 e podem rodar em paralelo
  - US3 (P2) pode começar após Foundational
  - US4 (P3) pode começar após Foundational
- **Polish (Phase 7)**: Depende de todas as desired user stories completas

### User Story Dependencies

- **US1 (P1)**: Pode começar após Foundational — Sem dependências de outras stories
- **US2 (P1)**: Pode começar após Foundational — Pode integrar com US1 mas deve ser independentemente testável
- **US3 (P2)**: Pode começar após Foundational — Pode integrar com US1/US2
- **US4 (P3)**: Pode começar após Foundational — Pode integrar com US1/US2/US3

### Within Each User Story

- Models antes de services
- Services antes de endpoints
- Core implementation antes de integration
- Story completa antes de mover para próxima prioridade

### Parallel Opportunities

- T001, T002, T003 (Setup) podem rodar em paralelo
- T004, T005, T006 (Foundational) podem rodar em paralelo
- US1 e US2 podem ser implementadas em paralelo
- T028, T029 (Polish) podem rodar em paralelo

---

## Parallel Example: User Story 1

```bash
# Todas as tasks de US1 podem ser executadas em sequência:
Task: "T007 Refatorar road.gd para pool de segmentos"
Task: "T008 Implementar cálculo de pool_size"
Task: "T009 Implementar update_scroll_speed()"
Task: "T010 Implementar loop de scrolling"
Task: "T011 Atualizar gameplay_manager.gd"
Task: "T012 Configurar segmentos iniciais"
```

---

## Implementation Strategy

### MVP First (User Story 1 + US2)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL)
3. Completar Phase 3: US1 (Road Visual with Scrolling)
4. Completar Phase 4: US2 (Road Loop and Segments)
5. **PARAR e VALIDAR**: Testar US1+US2 independentemente
6. Deploy/demo se pronto

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Adicionar US1+US2 → Testar independentemente → Deploy/Demo (MVP!)
3. Adicionar US3 → Testar independentemente → Deploy/Demo
4. Adicionar US4 → Testar independentemente → Deploy/Demo
5. Cada story adiciona valor sem quebrar stories anteriores

---

## Notes

- [P] tasks = arquivos diferentes, sem dependências
- [Story] label mapeia task para user story específica
- Cada user story deve ser independentemente completável e testável
- Commit após cada task ou grupo lógico
- Parar em qualquer checkpoint para validar story independentemente
- Evitar: tasks vagas, conflitos no mesmo arquivo, dependências cross-story
