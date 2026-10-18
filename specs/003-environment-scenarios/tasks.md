# Tasks: Sistema de Ambientes e Cenários

**Input**: Design documents from `/specs/003-environment-scenarios/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Estrutura de diretórios e configuração base

- [x] T001 Criar diretório `src/environment/` no projeto
- [x] T002 [P] Criar `src/environment/environment_data.gd` com classe EnvironmentData (id, display_name, texture_path, difficulty)
- [x] T003 Adicionar propriedades de ambiente ao `src/config/game_config.gd`: `current_environment_id` (String, padrão "PLAINS"), `background_multiplier` (float, padrão 0.6), e dicionário `ENVIRONMENTS` com os 4 ambientes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Componentes core que TODOS as user stories dependem

**⚠️ CRITICAL**: Nenhum trabalho de user story pode iniciar até esta fase estar completa

- [x] T004 Criar `src/environment/environment_manager.gd` com: set_environment(id), get_current_environment(), get_difficulty(), get_all_environments(), fallback para PLAINS em ID inválido com push_warning()
- [x] T005 Criar `src/environment/background_controller.gd` com: pool de 2 Sprite2D, set_texture(path), update_scroll(road_speed, delta), reset(), lógica de reciclagem vertical para seamless tiling

**Checkpoint**: Foundation pronta — implementação de user stories pode iniciar

---

## Phase 3: User Story 1 — Exibir Ambiente Visual com Background (Priority: P1) 🎯 MVP

**Goal**: O jogador visualiza um cenário de fundo que identifica o ambiente, com textura seamless preenchendo toda a tela.

**Independent Test**: Selecionar cada ambiente e verificar se o background correto é exibido, sem espaços vazios ou bordas.

### Implementation for User Story 1

- [x] T006 [US1] Adicionar BackgroundLayer (Node2D) como primeiro filho de `src/game/gameplay.tscn`, antes de Road, com script `background_controller.gd`
- [x] T007 [US1] Integrar BackgroundController no `src/game/gameplay_manager.gd`: carregar ambiente atual via EnvironmentManager ao iniciar, chamar set_texture() com o asset correspondente
- [x] T008 [US1] Verificar que a textura de grama (PLAINS) é exibida preenchendo toda a tela 640x480 sem espaços vazios
- [x] T009 [US1] Testar os 4 ambientes (PLAINS, DESERT, FOREST, ICE) verificando que cada background correto é exibido

**Checkpoint**: Background visual funcional — o jogo exibe o cenário correto para cada ambiente

---

## Phase 4: User Story 2 — Sincronizar Movimento do Background com a Estrada (Priority: P1)

**Goal**: O background acompanha visualmente o deslocamento da estrada, parando quando o jogador para.

**Independent Test**: Acelerar e frear o veículo, verificar que o background se move sincronizado com a estrada.

### Implementation for User Story 2

- [x] T010 [US2] Atualizar `src/game/gameplay_manager.gd` para chamar `background_controller.update_scroll(road_speed, delta)` no _process, passando a velocidade de scroll da estrada multiplicada por background_multiplier
- [x] T011 [US2] Implementar lógica de reciclagem em `background_controller.gd`: quando sprite sai pela parte inferior, reposicionar acima do sprite superior (seamless loop)
- [x] T012 [US2] Verificar que com velocidade zero o background para de se mover
- [x] T013 [US2] Verificar que a repetição da textura é visualmente contínua durante scroll (sem bordas ou cortes)

**Checkpoint**: Background sincronizado com a estrada — scroll visual coerente

---

## Phase 5: User Story 3 — Selecionar Ambiente por Configuração (Priority: P2)

**Goal**: O ambiente é selecionável por configuração, sem alterar código.

**Independent Test**: Alterar current_environment_id no GameConfig e verificar que o novo ambiente é carregado.

### Implementation for User Story 3

- [x] T014 [US3] Atualizar `src/game/gameplay_manager.gd` para ler `GameConfig.current_environment_id` e chamar `EnvironmentManager.set_environment()` antes de carregar o background
- [x] T015 [US3] Implementar lógica de fallback: se texture_path não existe, usar textura de PLAINS + push_warning()
- [x] T016 [US3] Testar troca de ambiente alterando GameConfig.current_environment_id para cada valor válido (PLAINS, DESERT, FOREST, ICE)

**Checkpoint**: Ambiente selecionável por configuração — troca sem modificar código

---

## Phase 6: User Story 4 — Manter Funcionalidade da Estrada Sobre Qualquer Ambiente (Priority: P1)

**Goal**: A estrada do SPEC-002 funciona perfeitamente sobre qualquer background.

**Independent Test**: Executar todas as funcionalidades da estrada (scrolling, transições de vias, limites) com cada ambiente.

### Implementation for User Story 4

- [x] T017 [US4] Executar teste de regressão: com cada ambiente ativo, verificar aceleração, frenagem, movimento lateral, limites da estrada
- [x] T018 [US4] Verificar transições de 2 para 4 vias e redução com pelo menos 2 ambientes diferentes
- [x] T019 [US4] Verificar que o background não interfere no scroll da estrada nem na dinâmica do veículo

**Checkpoint**: Zero regressões — estrada funciona idêntico em todos os ambientes

---

## Phase 7: User Story 5 — Fornecer Dificuldade Base para Sistemas Futuros (Priority: P3)

**Goal**: Cada ambiente disponibiliza seu nível de dificuldade para sistemas futuros.

**Independent Test**: Chamar get_difficulty() para cada ambiente e verificar valores corretos.

### Implementation for User Story 5

- [x] T020 [US5] Verificar que EnvironmentManager.get_difficulty() retorna 1 para PLAINS, 2 para DESERT, 3 para FOREST, 4 para ICE
- [x] T021 [US5] Verificar que get_difficulty() retorna 0 quando nenhum ambiente está selecionado

**Checkpoint**: Dificuldade base disponível para consumo por sistemas futuros

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Melhorias transversais e validação final

- [x] T022 [P] Criar testes unitários em `tests/unit/test_environment.gd` usando GdUnit4: EnvironmentData, EnvironmentManager (set/get/fallback/difficulty), BackgroundController (texture load, scroll, reset)
- [x] T023 Executar quickstart.md completo — validar todos os 7 cenários de teste manual
- [x] T024 Verificar preservação de pixel art: sem suavização, sem filtros, escala consistente em todos os ambientes
- [x] T024a [P] Ajustar assets de background para resolução nativa 640x480 e atualizar `background_controller.gd` para escala 1:1 (sem upscaling), mantendo reciclagem vertical e filtro NEAREST
- [x] T025 Revisão final de código: nomes descritivos, sem magic numbers, responsabilidades separadas

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências — iniciar imediatamente
- **Foundational (Phase 2)**: Depende do Setup — BLOQUEIA todas as user stories
- **User Stories (Phase 3-7)**: Todas dependem do Foundational
  - US1 (P1) e US2 (P1) podem progredir em paralelo após Foundational
  - US3 (P2) pode iniciar após Foundational
  - US4 (P1) requer US1 e US2 completos
  - US5 (P3) pode iniciar após Foundational
- **Polish (Phase 8)**: Depende de todas as user stories desejadas

### User Story Dependencies

- **US1 (P1)**: Após Foundational — sem dependências de outras stories
- **US2 (P1)**: Após Foundational — pode integrar com US1 mas é testável independentemente
- **US3 (P2)**: Após Foundational — pode integrar com US1/US2 mas é testável independentemente
- **US4 (P1)**: Requer US1 e US2 completos (verificação de regressão sobre background funcional)
- **US5 (P3)**: Após Foundational — verificação simples de dados

### Parallel Opportunities

- T002 e T003 podem rodar em paralelo (arquivos diferentes)
- T004 e T005 podem rodar em paralelo (arquivos diferentes)
- T008 e T009 são independentes
- T022 (testes) pode rodar em paralelo com T023-T025

---

## Parallel Example: User Story 1

```bash
# Tasks de US1 em sequência (dependem umas das outras):
T006: Adicionar BackgroundLayer ao gameplay.tscn
T007: Integrar BackgroundController no gameplay_manager.gd
T008: Verificar background PLAINS
T009: Testar os 4 ambientes
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL)
3. Completar Phase 3: User Story 1
4. **PARAR e VALIDAR**: Testar background exibindo corretamente para PLAINS
5. Demo pronta para visualização

### Incremental Delivery

1. Setup + Foundational → Foundation pronta
2. Adicionar US1 → Testar independentemente → Background visual funcional (MVP!)
3. Adicionar US2 → Testar independentemente → Scroll sincronizado
4. Adicionar US3 → Testar independentemente → Seleção por config
5. Adicionar US4 → Testar regressão → Zero quebras
6. Adicionar US5 → Testar dados → Dificuldade disponível
7. Cada story agrega valor sem quebrar stories anteriores

---

## Notes

- [P] tasks = arquivos diferentes, sem dependências
- [Story] label mapeia task à user story para rastreabilidade
- Cada user story deve ser completável e testável independentemente
- Commit após cada task ou grupo lógico
- Parar em qualquer checkpoint para validar story independentemente
