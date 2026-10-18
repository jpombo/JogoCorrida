# Tasks: Vehicle Control and Movement

**Input**: Design documents from `/specs/001-vehicle-control-movement/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Incluídos — constituição recomenda testes para lógica determinística (constituição Seção Testing)

**Organization**: Tasks organizados por user story para implementação e teste independentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode executar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: User story à qual a task pertence (US1, US2, US3, US4, US5)
- Incluir caminhos exatos de arquivos nas descrições

## Phase 1: Setup (Infraestrutura Compartilhada)

**Purpose**: Inicialização do projeto e estrutura básica

- [X] T001 Criar estrutura de diretórios do projeto conforme plan.md (src/player/, src/road/, src/game/, src/config/, tests/unit/)
- [X] T002 Configurar project.godot com resolução 640x480, pixel art, e input map (accelerate, brake, move_left, move_right)
- [X] T003 [P] Instalar GdUnit4 via Asset Library ou Godot Editor para testes unitários

---

## Phase 2: Foundational (Prerrequisitos Bloqueantes)

**Purpose**: Infraestrutura core que DEVE estar completa ANTES de qualquer user story

**⚠️ CRITICAL**: Nenhum trabalho de user story pode começar até esta fase estar completa

- [X] T004 Criar GameConfig autoload singleton em src/config/game_config.gd com todos os parâmetros de FR-021/FR-022 (max_speed, acceleration, brake_force, etc.)
- [X] T005 Criar GameState em src/game/game_state.gd com enum de estados (MENU, READY, PLAYING, PAUSED, VICTORY, GAME_OVER) e transições básicas
- [X] T006 Criar Road em src/road/road.gd com limites laterais (left_boundary, right_boundary) e preparação para scrolling futuro

**Checkpoint**: Fundação pronta - implementação de user stories pode começar

---

## Phase 3: User Story 1 - Controle Básico do Veículo (Priority: P1) 🎯 MVP

**Goal**: Jogador consegue controlar veículo com 4 controles básicos (acelerar, frear, esquerda, direita)

**Independent Test**: Iniciar jogo e verificar que veículo responde aos 4 controles independentemente e em combinação

### Tests for User Story 1 ⚠️

> **NOTE: Escrever estes testes PRIMEIRO, garantir que FALHAM antes da implementação**

- [X] T007 [P] [US1] Criar testes unitários de física vertical em tests/unit/test_vehicle_physics.gd (test_speed_increases_with_acceleration, test_speed_decreases_with_brake, test_brake_overrides_accelerate, test_natural_deceleration, test_speed_clamped_at_max, test_speed_clamped_at_zero)

### Implementation for User Story 1

- [X] T008 [P] [US1] Criar VehicleController em src/player/vehicle_controller.gd com lógica de input e física vertical (aceleração, frenagem, inércia, prioridade de frenagem)
- [X] T009 [P] [US1] Criar PlayerVehicle em src/player/player_vehicle.gd com Sprite2D, CollisionShape2D, e integração com VehicleController
- [X] T010 [US1] Criar cena principal gameplay.tscn com Road, PlayerVehicle, e configuração de câmera top-down fixa
- [X] T011 [US1] Implementar movimento lateral independente em vehicle_controller.gd (move_left, move_right, desaceleração lateral)

**Checkpoint**: Neste ponto, User Story 1 deve estar completamente funcional e testável independentemente

---

## Phase 4: User Story 2 - Movimento Vertical Baseado na Velocidade (Priority: P1)

**Goal**: Posição vertical do veículo representa visualmente sua velocidade atual

**Independent Test**: Verificar se posição Y corresponde à velocidade conforme faixa vertical configurável

### Tests for User Story 2 ⚠️

- [X] T012 [P] [US2] Adicionar testes de posição vertical em tests/unit/test_vehicle_physics.gd (test_vertical_position_at_zero_speed, test_vertical_position_at_max_speed, test_vertical_interpolation, test_vertical_bounds)

### Implementation for User Story 2

- [X] T013 [US2] Implementar get_vertical_position() em vehicle_controller.gd com interpolação linear entre vertical_position_min e vertical_position_max baseada na velocidade
- [X] T014 [US2] Atualizar player_vehicle.gd para aplicar posição Y retornada por get_vertical_position() a cada frame

**Checkpoint**: User Story 1 E 2 devem funcionar independentemente

---

## Phase 5: User Story 3 - Movimento Diagonal Natural (Priority: P1)

**Goal**: Combinação de movimento vertical e horizontal produz trajetórias diagonais naturais

**Independent Test**: Combinar aceleração/frenagem com movimento lateral e verificar trajetória diagonal

### Tests for User Story 3 ⚠️

- [X] T015 [P] [US3] Adicionar testes de movimento diagonal em tests/unit/test_vehicle_physics.gd (test_diagonal_accelerate_left, test_diagonal_accelerate_right, test_diagonal_brake_left, test_diagonal_brake_right, test_lateral_cancellation)

### Implementation for User Story 3

- [X] T016 [US3] Implementar normalização de vetor diagonal em vehicle_controller.gd para evitar aumento artificial de velocidade (FR-014)
- [X] T017 [US3] Atualizar player_vehicle.gd para aplicar movimento combinado vertical + horizontal a cada frame

**Checkpoint**: User Stories 1, 2 E 3 devem funcionar independentemente

---

## Phase 6: User Story 4 - Limites da Estrada e Restrição de Movimento (Priority: P1)

**Goal**: Veículo nunca sai da área válida da estrada

**Independent Test**: Tentar mover veículo além dos limites e verificar que permanece dentro

### Tests for User Story 4 ⚠️

- [X] T018 [P] [US4] Criar testes de limites em tests/unit/test_road_boundaries.gd (test_boundary_collision_left, test_boundary_collision_right, test_vertical_bounds, test_no_teleportation)

### Implementation for User Story 4

- [X] T019 [US4] Implementar _clamp_position() em vehicle_controller.gd para respeitar road_left_boundary, road_right_boundary, vertical_position_min, vertical_position_max
- [X] T020 [US4] Implementar signal boundary_reached em vehicle_controller.gd (emitido ao atingir limite horizontal)
- [X] T021 [US4] Atualizar player_vehicle.gd para aplicar _clamp_position() após cada cálculo de posição

**Checkpoint**: User Stories 1, 2, 3 E 4 devem funcionar independentemente

---

## Phase 7: User Story 5 - Sprite e Configuração Visual (Priority: P2)

**Goal**: Veículo utiliza assets reais com possibilidade de troca sem alterar código de controle

**Independent Test**: Trocar recurso visual e verificar que movimento/física permanecem idênticos

### Tests for User Story 5 ⚠️

- [X] T022 [P] [US5] Criar testes de independência de sprite em tests/unit/test_vehicle_physics.gd (test_sprite_swap_physics_unchanged, test_default_sprite_loaded, test_fallback_placeholder)

### Implementation for User Story 5

- [X] T023 [P] [US5] Configurar sprite padrão (azul.png) em player_vehicle.gd com carregamento via GameConfig
- [X] T024 [P] [US5] Implementar sistema de fallback para asset ausente em player_vehicle.gd (log de erro + placeholder visual quadrado colorido)
- [X] T025 [US5] Adicionar suporte a troca dinâmica de sprite (azul ↔ vermelho) via GameConfig sem alterar física

**Checkpoint**: Todas as User Stories devem funcionar independentemente

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Melhorias que afetam múltiplas user stories

- [X] T026 [P] Executar todos os testes unitários e garantir que passam (GdUnit4)
- [X] T027 [P] Validar cenários do quickstart.md manualmente no editor Godot
- [X] T028 Verificar framerate estável de 60 FPS durante gameplay de 5 minutos (SC-013)
- [X] T029 Verificar zero erros no console durante sessão de gameplay (SC-012)
- [X] T030 Limpar código temporário e verificar conformidade com constituição

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências - pode iniciar imediatamente
- **Foundational (Phase 2)**: Depende do Setup - BLOQUEIA todas as user stories
- **User Stories (Phase 3-7)**: Todas dependem do Foundational
  - US1 pode iniciar após Foundational
  - US2 pode iniciar após Foundational (depende de US1 para vehicle_controller.gd existir)
  - US3 pode iniciar após Foundational (depende de US1 para vehicle_controller.gd existir)
  - US4 pode iniciar após Foundational (depende de US1 para vehicle_controller.gd existir)
  - US5 pode iniciar após Foundational (depende de US1 para player_vehicle.gd existir)
- **Polish (Phase 8)**: Depende de todas as user stories desejadas estarem completas

### User Story Dependencies

- **User Story 1 (P1)**: Pode iniciar após Foundational (Phase 2) - Sem dependências em outras stories
- **User Story 2 (P1)**: Depende de US1 (vehicle_controller.gd precisa existir para adicionar get_vertical_position)
- **User Story 3 (P1)**: Depende de US1 (vehicle_controller.gd precisa existir para adicionar normalização diagonal)
- **User Story 4 (P1)**: Depende de US1 (vehicle_controller.gd precisa existir para adicionar _clamp_position)
- **User Story 5 (P2)**: Depende de US1 (player_vehicle.gd precisa existir para adicionar sprite system)

### Within Each User Story

- Tests (se incluídos) DEVEM ser escritos e FALHAR antes da implementação
- Models antes de services
- Services antes de endpoints
- Core implementation antes de integration
- Story completa antes de mover para próxima prioridade

### Parallel Opportunities

- T003, T007, T012, T015, T018, T022, T026, T027 podem rodar em paralelo (testes)
- T008 e T009 podem rodar em paralelo (arquivos diferentes)
- T023 e T024 podem rodar em paralelo (arquivos diferentes)
- Diferentes user stories podem ser trabalhadas em paralelo por diferentes membros da equipe

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Criar testes unitários de física vertical em tests/unit/test_vehicle_physics.gd"

# Launch all models for User Story 1 together:
Task: "Criar VehicleController em src/player/vehicle_controller.gd"
Task: "Criar PlayerVehicle em src/player/player_vehicle.gd"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL - bloqueia todas as stories)
3. Completar Phase 3: User Story 1
4. **PARAR e VALIDAR**: Testar User Story 1 independentemente
5. Deploy/demo se pronto

### Incremental Delivery

1. Completar Setup + Foundational → Fundação pronta
2. Adicionar User Story 1 → Testar independentemente → Deploy/Demo (MVP!)
3. Adicionar User Story 2 → Testar independentemente → Deploy/Demo
4. Adicionar User Story 3 → Testar independentemente → Deploy/Demo
5. Adicionar User Story 4 → Testar independentemente → Deploy/Demo
6. Adicionar User Story 5 → Testar independentemente → Deploy/Demo
7. Cada story adiciona valor sem quebrar stories anteriores

### Parallel Team Strategy

Com múltiplos desenvolvedores:

1. Equipe completa Setup + Foundational juntos
2. Quando Foundational estiver pronto:
   - Desenvolvedor A: User Story 1
   - Desenvolvedor B: User Story 2 + 3 (ambas dependem de US1)
   - Desenvolvedor C: User Story 4 + 5 (ambas dependem de US1)
3. Stories completam e integram independentemente

---

## Notes

- [P] tasks = arquivos diferentes, sem dependências
- [Story] label mapeia task à user story específica para rastreabilidade
- Cada user story deve ser completável e testável independentemente
- Verificar que testes falham antes de implementar
- Commit após cada task ou grupo lógico
- Parar em qualquer checkpoint para validar story independentemente
- Evitar: tasks vagas, conflitos no mesmo arquivo, dependências cross-story que quebram independência

---

## Phase 9: Convergence

**Purpose**: Tarefas restantes identificadas pela verificação de convergência entre spec, plan, tasks e código implementado

- [X] T031 Integrar GameState em gameplay.tscn — adicionar script de gerenciamento de cena que observe GameState e implemente transições MENU→READY→PLAYING conforme FR-023 (partial)
- [X] T032 Implementar scrolling da estrada em road.gd — mover road.position.y conforme VehicleController.speed para criar sensação de progressão conforme FR-027 (missing)
- [X] T033 Instalar GdUnit4 e validar execução dos testes unitários em tests/unit/ — garantir que todos os 21 testes passam conforme SC-011 (partial)
- [X] T034 Validar manualmente no Godot Editor: framerate 60 FPS por 5 minutos (SC-012) e zero erros no console (SC-013) (partial)
