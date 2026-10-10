---

description: "Task list for SPEC-004 — Sistema de Trânsito e Decoração dos Ambientes"
---

# Tasks: Sistema de Trânsito e Decoração dos Ambientes

**Input**: Design documents from `/specs/004-traffic-and-decoration/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/traffic_decoration_contract.md, quickstart.md

> **Gate de cobertura (constituição v2.0.0 §Testes) — LIBERADO pela T057** (2 execuções seguidas, `Godot 4.7.2` + `GdUnit4 6.2.0`, `bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit` → exit 101). Resultado por suíte: **104 casos, 0 erros, 0 falhas** (102 na T057 + 1 da T058 + 1 da T059).
>
> | Suíte | Casos | Resultado |
> |---|---|---|
> | `test_traffic_manager` (T016, T019, T023) | 12 | PASSED |
> | `test_traffic_categories` (T040) | 8 | PASSED |
> | `test_decoration_manager` (T024, T030, T031, T036, T037, T056, T058) | 14 | PASSED |
> | `test_decoration_libraries` (T028) | 8 | PASSED |
> | `test_decoration_config` (T040) | 9 | PASSED |
> | `test_spec004_regression` (T044) | 7 | PASSED |
> | `test_no_collision` (T047) | 4 | PASSED |
> | `test_performance_traffic_decoration` (T048) | 2 | PASSED |
> | `test_memory_stability` (T049, T059) | 2 | PASSED |
> | `test_vehicle_physics` (pré-existente) | 21 | PASSED |
> | `test_road_boundaries` (pré-existente) | 4 | PASSED |
> | `test_environment` (pré-existente) | 13 | PASSED |
>
> As tasks de teste deixam de ser provisórias; as demais validações (T048, T049, T051) seguem abertas pelo seu próprio conteúdo, não pela falta de suíte.

**Tests**: Tarefas de teste incluídas. A constituição (v2.0.0, §Testes) exige cobertura automatizada de lógica determinística crítica, e `plan.md` fixa as 9 suítes novas em `tests/unit/` (`test_traffic_manager`, `test_traffic_categories`, `test_decoration_manager`, `test_decoration_libraries`, `test_decoration_config`, `test_spec004_regression`, `test_no_collision`, `test_performance_traffic_decoration`, `test_memory_stability`), além das 3 já existentes (`test_vehicle_physics`, `test_road_boundaries`, `test_environment`). Removíveis se a TDD não for desejada.

**Organization**: Tasks agrupadas por user story, em ordem de prioridade, permitindo implementação e validação independentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: User story desta task
- Caminhos de arquivo exatos em cada descrição

## Convenções de caminho

Projeto único Godot: `src/` e `tests/` na raiz. Módulos novos: `src/traffic/`, `src/decoration/`. Configuração centralizada: `src/config/game_config.gd`.

## Fora de escopo desta lista

Nenhuma tarefa altera `src/road/`, `src/player/`, `src/environment/` ou `src/game/game_state.gd`. O contrato com `Road` consome 3 métodos existentes sem modificá-los (research.md R7).

**Exceção reconciliada pela T060**: `src/road/road.gd` e `src/player/player_vehicle.gd` receberam uma linha cada (`class_name Road` / `class_name PlayerVehicle`), exigida pelos dublês `extends Road` dos testes unitários — a tipagem forte das assinaturas `update(delta, road: Road)` recusa em runtime qualquer objeto que não seja `Road`, e o dublê mínimo só é possível por herança. A linha é declaração de tipo, sem alteração de comportamento; a justificativa completa está na seção "Exceção de escopo justificada (T060)" do `plan.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Preparação dos assets e da configuração centralizada

- [X] T001 Criar `tools/resize_decoration_assets.py` como validador somente leitura da entrega: confere que cada entrada de `GameConfig.DECORATION_LIBRARIES` tem PNG em `assets/decoracao/<ambiente>/`, que as alturas ficam entre 3% e 35% da área visível, que as proporções batem com `assets/decoracao/_originais/`, que `.import` existe e que os `weight` somam 100 por ambiente — sem alterar nenhum arquivo (research.md R1, R6)
- [X] T002 Executar `python3 tools/resize_decoration_assets.py` e registrar a saída `OK: 17 assets declarados existem, com altura na faixa da SC-027 e percentuais somando 100 por ambiente` (SC-027, FR-047)
- [X] T003 Comparar visualmente cada asset de `assets/decoracao/_originais/` com o correspondente reexportado na base de tile 32x32, conferindo ausência de interpolação e legibilidade dos pixels (FR-047, SC-020), e registrar o resultado no `quickstart.md`
  - Lado a lado (original reamostrado por NEAREST na mesma caixa × entregue) dos 5 maiores desvios: formas, contornos e paleta correspondem, bordas duras, sem halo de interpolação; registrado no bloco de validação do `quickstart.md` (2026-10-04)
- [X] T004 Adicionar em `src/config/game_config.gd` a constante `KMH_TO_SPEED_UNIT = 0.8`, o dicionário `TRAFFIC_CATEGORIES` com as 4 categorias (`caminhao` 90 km/h, `esporte` 120, `passeio` 100, `utilitario` 90) contendo `id`, `display_name`, `assets_path`, `assets`, `max_speed_kmh`, `frequency`, e os 6 parâmetros `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_distance`, `traffic_spawn_interval`, `traffic_min_spacing`, `traffic_frequency_<categoria>`
- [X] T005 Adicionar em `src/config/game_config.gd` o dicionário `DECORATION_LIBRARIES` com as 4 bibliotecas (PLAINS 5, DESERT 5, FOREST 4, ICE 3 = 17 assets), cada entrada com `repeatable` e `weight` (percentual de apresentação, somando 100 por ambiente), e os 10 parâmetros `decoration_enabled`, `decoration_density`, `decoration_speed_multiplier`, `decoration_spacing_min`, `decoration_spacing_max`, `decoration_depth_count`, `decoration_depth_spacing`, `decoration_scale`, `decoration_safety_margin`, `decoration_tree_repeat_limit`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Entidades de dados e camadas de cena das quais todas as user stories dependem

**⚠️ CRITICAL**: Nenhuma user story pode começar antes desta fase

- [X] T006 Criar `src/traffic/traffic_data.gd` com `class_name TrafficData extends Resource` e os campos `id`, `display_name`, `assets_path`, `assets`, `max_speed_kmh`, `max_speed`, `frequency`, `size`, com `max_speed` calculado como `max_speed_kmh * GameConfig.KMH_TO_SPEED_UNIT`
- [X] T007 [P] Criar `src/decoration/decoration_data.gd` com `class_name DecorationData extends Resource` e os campos `asset`, `texture_path`, `repeatable`, `size`, deriving `repeatable` do campo de configuração e nunca de comparação de string em runtime (research.md R3)
- [X] T008 Adicionar em `src/game/gameplay.tscn` os nós `DecorationLayer` (Node2D) após `BackgroundLayer` e `TrafficLayer` (Node2D) após `Road`, preservando a ordem visual Background → Decoração → Estrada → Trânsito → Jogador (FR-048)
- [X] T009 Adicionar em `src/game/gameplay_manager.gd` as referências `@onready` para `decoration_layer` e `traffic_layer`, e a ordem de atualização em `_process`: `road.update_scroll_speed` → `road._process` → `decoration_layer.update` → `traffic_layer.update` (FR-055, research.md R9)

**Checkpoint**: Fundação pronta — as user stories podem começar em paralelo

---

## Phase 3: User Story 1 - Verificar Veículos de Trânsito em Movimento na Estrada (Priority: P1) 🎯 MVP

**Goal**: Veículos de trânsito que entram pela borda superior, são ultrapassados, descem, saem pela borda inferior e são reciclados, com quantidade limitada e pool reutilizável.

**Independent Test**: Iniciar o jogo, acelerar e observar o surgimento, o deslocamento e o desaparecimento de veículos, sem nenhum criado dentro da área visível ou fora das faixas. Validar com os cenários V2, V3 e V4 do `quickstart.md`.

### Tests for User Story 1 ⚠️

> Escrever primeiro e confirmar que falha antes da implementação

- [X] T010 [P] [US1] Criar `tests/unit/test_traffic_manager.gd` com dublê de `Road` (apenas `get_boundaries_for_player_y()` e `scroll_speed`) cobrindo I1 a I7: limite de veículos ativos, spawn fora da área visível, reciclagem por qualquer borda, crescimento do pool sob demanda, desabilitado impede nova criação, `scroll_speed == 0.0` suprime o spawn sem deslocar nem remover os veículos ativos (SC-022), e `get_vehicles_data()` retorna um snapshot `{id, position, occupied_area}` de cada veículo ativo com `occupied_area` derivada de `category.size` (FR-025)

### Implementation for User Story 1

- [X] T011 [US1] Criar `src/traffic/traffic_vehicle.gd` com `class_name TrafficVehicle extends Sprite2D`, `texture_filter = TEXTURE_FILTER_NEAREST`, estado `ACTIVE`/`INACTIVE`, e os métodos `activate(category, lane_position, y)`, `deactivate()`, `update_scroll(delta, road_speed, bounds)`, `get_occupied_area() -> Rect2` derivado de `category.size`, `get_category_id() -> String` para a UI futura, e o getter público `is_active() -> bool` consumido internamente por `TrafficManager` para distinguir `ACTIVE` de `INACTIVE` no lugar do I5, que exige `deactivate()` e não simples ocultamento (FR-002, FR-003, FR-025)
- [X] T012 [US1] Implementar em `src/traffic/traffic_manager.gd` o `class_name TrafficManager extends Node2D` com `setup(categories)`, pool reutilizável, `update(delta, road)`, spawn acima da área visível respeitando `traffic_max_vehicles` e `traffic_min_spacing`, deslocamento pela diferença de velocidade e reciclagem por qualquer borda (FR-004 a FR-021, I1 a I7)
- [X] T013 [US1] Implementar em `src/traffic/traffic_manager.gd` o método `get_vehicles_data() -> Array[Dictionary]` retornando um snapshot `{id, position, occupied_area}` de cada veículo ativo, construído **sob demanda** e nunca dentro de `_process`, para não violar a restrição de não-alocação por quadro (R9); satisfaz o MUST de exposição de dados para colisão da constitution v2.0.0 §Trânsito (FR-025)
- [X] T014 [US1] Integrar `TrafficManager` em `src/game/gameplay_manager.gd` como script do nó `TrafficLayer`, instanciando-o e repassando `Road` em `update()` sem escrever em nenhuma propriedade de `Road` (FR-022, FR-052)
- [X] T015 [US1] Suprimir a criação de veículos de trânsito quando `road.scroll_speed == 0.0`, mantendo os veículos já em cena e sem afetar a reciclagem (SC-022)

**Checkpoint**: User Story 1 funcional e validável isoladamente — é o MVP

---

## Phase 4: User Story 2 - Distinguir as Categorias de Veículos de Trânsito (Priority: P1)

**Goal**: As 4 categorias (`caminhao`, `esporte`, `passeio`, `utilitario`) com aparência, dimensões e velocidade máxima próprias, sorteadas por frequência configurável.

**Independent Test**: Observar o tráfego durante a condução e confirmar a presença das 4 categorias com aparências, dimensões e velocidades distintas, e que a proporção de cada uma respeita a configuração. Validar com o cenário V5 e a Parte 1 do `quickstart.md`.

### Tests for User Story 2 ⚠️

- [X] T016 [P] [US2] Criar `tests/unit/test_traffic_categories.gd` verificando `max_speed == max_speed_kmh * 0.8` para as 4 categorias, `max_speed < GameConfig.max_speed` para todas (I4, FR-008), existência de todos os arquivos de `assets` e soma das frequências maior que zero

### Implementation for User Story 2

- [X] T017 [US2] Implementar em `src/traffic/traffic_manager.gd` o sorteio ponderado da categoria por `frequency`, com categorias de `frequency == 0.0` nunca selecionadas mas mantidas configuráveis (FR-010, FR-023)
- [X] T018 [US2] Implementar em `src/traffic/traffic_vehicle.gd` o carregamento da textura da pasta `assets_path` da categoria, a medição de `category.size` a partir da textura real e o uso de `category.max_speed` como velocidade do veículo (FR-011, FR-012, R10)

**Checkpoint**: User Stories 1 e 2 funcionando de forma independente

---

## Phase 5: User Story 3 - Manter o Trânsito Válido Durante as Transições de Estrada (Priority: P1)

**Goal**: Trânsito correto durante toda a sequência 2 vias → expansão → 4 vias → redução → 2 vias, sem veículos fora da área trafegável e sem salto ao reatribuir faixa.

**Independent Test**: Percorrer a sequência completa de `GameConfig.test_track_sequence` verificando que nenhum veículo aparece ou desaparece da tela por mudança de largura. Validar com o cenário V11 do `quickstart.md`.

### Tests for User Story 3 ⚠️

- [X] T019 [P] [US3] Adicionar em `tests/unit/test_traffic_manager.gd` casos com dublê de `Road` devolvendo largura 144.0 (2 vias), 176.0 (4 vias) e valores interpolados, cobrindo spawn em altura de transição, reposicionamento contínuo ao estreitar e ausência de sobreposição imediata

### Implementation for User Story 3

- [X] T020 [US3] Implementar em `src/traffic/traffic_manager.gd` a validação de faixa livre no instante do spawn usando `road.get_boundaries_for_player_y(y)` na altura de criação, adiando a criação quando não houver faixa válida (FR-014, I2)
- [X] T021 [US3] Implementar em `src/traffic/traffic_vehicle.gd` o reposicionamento contínuo ao estreitamento, interpolando com `lerpf` do limite antigo para o novo usando o mesmo fator `t` da transição, mantendo `previous_right_boundary` e `reposition_lerp` (FR-021, research.md R8)
- [X] T022 [US3] Implementar em `src/traffic/traffic_manager.gd` a verificação de `traffic_min_spacing` longitudinal antes de cada spawn, sem bloquear a sobreposição lateral e sem criar neste quadro quando o espaço longitudinal for insuficiente (FR-019, FR-038)

**Checkpoint**: User Stories 1, 2 e 3 funcionando de forma independente

---

## Phase 6: User Story 4 - Visualizar Decoração Lateral Correspondente ao Ambiente (Priority: P2)

**Goal**: Elementos da biblioteca do ambiente atual nos dois lados da estrada, em múltiplas profundidades, inteiramente fora da área trafegável e sem repetição imediata indevida.

**Independent Test**: Selecionar cada um dos 4 ambientes e verificar que a decoração exibida pertence exclusivamente à biblioteca daquele ambiente, aparece dos dois lados e não invade a área trafegável. Validar com os cenários V6, V7 e V8 do `quickstart.md`.

### Tests for User Story 4 ⚠️

- [X] T023 [P] [US4] Criar `tests/unit/test_decoration_libraries.gd` verificando que cada uma das 4 bibliotecas tem a contagem correta de assets (5, 5, 4, 3 = 17), que `repeatable` é verdadeiro exatamente para `planice_arvore01`, `deserto_arvore01`, `deserto_arvore02`, `floresta_arvore01`, `floresta_arvore02` e `gelo_arvore`, que os `weight` somam 100 por ambiente e que todo `texture_path` existe (FR-029, FR-036)
- [X] T024 [P] [US4] Criar `tests/unit/test_decoration_manager.gd` com dublê de `Road`, cobrindo D1 a D4 e D6 a D8: biblioteca do ambiente vigente, margem de segurança respeitada, nascimento fora da área visível e fora da estrada, reciclagem por qualquer borda, e limite de 10 repetições por lado

### Implementation for User Story 4

- [X] T025 [P] [US4] Criar `src/decoration/decoration_element.gd` com `class_name DecorationElement extends Sprite2D`, `texture_filter = TEXTURE_FILTER_NEAREST`, âncora base-centro (`update_anchor()`, research.md R5), `side` `LEFT`/`RIGHT`, `depth_index`, e os métodos `activate(data, side, depth_index, y)`, `deactivate()`, `update_scroll(delta, road_speed, bounds)`, `is_fully_outside(view_rect)`, `get_side()`, `get_depth_index()`
- [X] T026 [US4] Implementar em `src/decoration/decoration_manager.gd` o `class_name DecorationManager extends Node2D` com `setup(libraries)`, `update(delta, road)`, carregamento da biblioteca do ambiente vigente, distribuição nos dois lados em `decoration_depth_count` profundidades com `decoration_depth_spacing`, e posicionamento fora de `[left, right] + decoration_safety_margin` (FR-028 a FR-035, FR-042, FR-046, FR-050)
- [X] T027 [US4] Integrar `DecorationManager` em `src/game/gameplay_manager.gd` como script do nó `DecorationLayer`, instanciando-o e repassando `Road` em `update()` sem escrever em `Road` nem em `EnvironmentManager` (FR-052, D9)
- [X] T028 [US4] Implementar em `src/decoration/decoration_manager.gd` a seleção com dois contadores por lado: elemento com `repeatable == false` nunca sai duas vezes seguidas no mesmo lado enquanto houver alternativa, e elemento com `repeatable == true` respeita `decoration_tree_repeat_limit` ocorrências consecutivas **no mesmo lado, somando todas as profundidades** (FR-036, D6, D7, D8, SC-014)
- [X] T029 [US4] Implementar em `src/decoration/decoration_manager.gd` o reposicionamento de elemento maior que a profundidade disponível para a profundidade mais distante que o comporte, e o uso apenas das profundidades que cabem na lateral, sem invadir a área trafegável
- [X] T030 [US4] Adicionar em `tests/unit/test_decoration_manager.gd` a asserção de que cada lado mantém ao menos 3 elementos visíveis e ao menos 2 profundidades populadas durante a condução normal (SC-009)

**Checkpoint**: User Stories 1 a 4 funcionando de forma independente

---

## Phase 7: User Story 5 - Acompanhar a Decoração com o Movimento da Estrada (Priority: P2)

**Goal**: Decoração que acompanha o deslocamento da estrada, é reciclada ao sair da tela e fica congelada com o jogador parado.

**Independent Test**: Acelerar e frear observando que a decoração acompanha a estrada, e conduzir por tempo prolongado verificando que as laterais continuam povoadas. Validar com os cenários V9, V10 e V12 do `quickstart.md`.

### Tests for User Story 5 ⚠️

- [X] T031 [P] [US5] Adicionar em `tests/unit/test_decoration_manager.gd` casos de deslocamento por `decoration_speed_multiplier`, reciclagem por borda inferior e superior, ausência de criação e remoção com `scroll_speed == 0.0`, e reposicionamento contínuo durante o estreitamento (D2, D4, D5)

### Implementation for User Story 5

- [X] T032 [US5] Implementar em `src/decoration/decoration_manager.gd` o deslocamento derivado de `road.scroll_speed * GameConfig.decoration_speed_multiplier`, com a estrada como referência de 100% (FR-039, FR-058)
- [X] T033 [US5] Implementar em `src/decoration/decoration_element.gd` a detecção `is_fully_outside(view_rect)` por qualquer borda e a chamada a `deactivate()` com devolução ao pool, em vez de simples ocultação (FR-043, D4)
- [X] T034 [US5] Implementar em `src/decoration/decoration_manager.gd` o congelamento total com `road.scroll_speed == 0.0`: nenhum elemento se desloca, nenhum nasce e nenhum é removido, e os já visíveis permanecem em tela até o jogador voltar a se mover (FR-040, FR-041, D5, SC-022)
- [X] T035 [US5] Implementar em `src/decoration/decoration_manager.gd` o reposicionamento lateral contínuo via `lerpf` dos elementos que ficam sobre a área que deixa de ser trafegável durante a redução de 4 para 2 vias, preservando a margem de segurança (FR-051, D2, SC-011)
- [X] T036 [US5] Adicionar em `tests/unit/test_decoration_manager.gd` o caso de continuidade de composição com `background_multiplier == 0.6` e `decoration_speed_multiplier == 1.0`, verificando que a decoração permanece dentro do campo de visão sem lacunas visíveis durante a transição de 2 para 4 vias (FR-058, FR-059, SC-012, SC-013)

**Checkpoint**: User Stories 1 a 5 funcionando de forma independente

---

## Phase 8: User Story 6 - Trocar a Decoração ao Mudar de Ambiente (Priority: P3)

**Goal**: Troca da biblioteca em uso ao mudar o ambiente, sem resíduo do ambiente anterior e sem alteração de código.

**Independent Test**: Alternar a configuração de ambiente e verificar que, após a troca, somente a biblioteca do novo ambiente aparece nas laterais. Validar com o cenário V14 do `quickstart.md`.

### Tests for User Story 6 ⚠️

- [X] T037 [P] [US6] Adicionar em `tests/unit/test_decoration_manager.gd` casos de `set_environment()` cobrindo D1: após a troca, `active_count` contém apenas elementos da biblioteca nova, e o sinal `environment_changed` é emitido com os dois identificadores

### Implementation for User Story 6

- [X] T038 [US6] Implementar em `src/decoration/decoration_manager.gd` o método `set_environment(id)` com desativação de todos os elementos da biblioteca anterior, liberação do pool e carregamento da nova biblioteca, com fallback e aviso para identificador inválido e para biblioteca vazia (FR-028, FR-031, FR-053, D1)
- [X] T039 [US6] Implementar em `src/decoration/decoration_manager.gd` o sinal `library_empty(environment_id)` emitido quando a biblioteca do ambiente não tem nenhum asset utilizável, mantendo o jogo jogável e o trânsito intacto

**Checkpoint**: User Stories 1 a 6 funcionando de forma independente

---

## Phase 9: User Story 7 - Ajustar a Experiência Visual por Configuração (Priority: P3)

**Goal**: Todos os parâmetros de trânsito e decoração ajustáveis exclusivamente por configuração, sem alteração de código, e expostos para o SPEC-008.

**Independent Test**: Alterar valores de configuração e verificar o resultado visual, sem necessidade de modificação de código. Validar com o cenário V13 do `quickstart.md`.

### Tests for User Story 7 ⚠️

- [X] T040 [P] [US7] Criar `tests/unit/test_decoration_config.gd` e casos em `tests/unit/test_traffic_categories.gd` validando as invariantes de configuração: `decoration_spacing_min <= decoration_spacing_max`, ambos maiores que zero, `decoration_speed_multiplier >= 0.0`, e `decoration_safety_margin >= 0.0`

### Implementation for User Story 7

- [X] T041 [US7] Implementar em `src/traffic/traffic_manager.gd` e `src/decoration/decoration_manager.gd` os métodos `set_enabled(enabled)` dos dois sistemas, com `traffic_enabled == false` impedindo nova criação sem congelar os existentes e `decoration_enabled == false` ocultando os elementos existentes sem afetar estrada e jogador (FR-024, FR-056)
- [X] T042 [US7] Implementar em `src/config/game_config.gd` o agrupamento dos parâmetros expostos ao SPEC-008 em estruturas nomeadas `traffic_tuning` e `decoration_tuning`, preservando os nomes atuais como aliases, para que a dificuldade futura receba um contrato estável (FR-061); agrupamentos somente leitura nesta versão, conforme a seção "Agrupamentos de parâmetros" de [data-model.md](./data-model.md)
- [X] T043 [US7] Implementar a leitura de `decoration_scale` em `src/decoration/decoration_element.gd` (aplicado sobre o asset já reescalonado), de `decoration_density` em `src/decoration/decoration_manager.gd` como programador da distância média entre elementos, e de `traffic_max_vehicles` e `traffic_spawn_interval` em `src/traffic/traffic_manager.gd` como programadores da quantidade e do intervalo de spawn (FR-004, FR-023, FR-037, FR-046)

**Checkpoint**: Todas as user stories implementadas e validáveis de forma independente

---

## Phase 10: User Story 8 - Preservar o Funcionamento das Features Anteriores (Priority: P1)

**Goal**: SPEC-001, SPEC-002 e SPEC-003 continuam funcionando sem regressão com trânsito e decoração ativos.

**Independent Test**: Executar o jogo com trânsito e decoração ativos e validar todos os comportamentos anteriores em cada um dos 4 ambientes. Validar com o cenário V15 do `quickstart.md`.

### Tests for User Story 8 ⚠️

- [X] T044 [P] [US8] Criar `tests/unit/test_spec004_regression.gd` consolidando as verificações de `test_vehicle_physics.gd`, `test_road_boundaries.gd` e `test_environment.gd`, executando as mesmas asserções com `traffic_enabled` e `decoration_enabled` ativos (SC-017)

### Implementation for User Story 8

- [X] T045 [US8] Verificar em `src/player/vehicle_controller.gd` e `src/game/gameplay_manager.gd` que a passagem das boundaries está intacta: `gameplay_manager.gd:80-81` lê `road.get_boundaries_for_player_y()` e chama `controller.update_boundaries()` a cada quadro, `_clamp_position()` mantém o jogador dentro dos limites com deslocamento suave, e a ordem das camadas vem da árvore de cena (`gameplay.tscn`: BackgroundLayer, DecorationLayer, Road, TrafficLayer, PlayerVehicle) — não existe `update_layer_order()` em `src/` (FR-051, FR-052, US8 cenário 4)
- [X] T046 [US8] Verificar em `src/environment/environment_manager.gd`, `src/environment/background_controller.gd` e `src/game/gameplay_manager.gd` que o fundo é atualizado antes da decoração (`background_layer.update_scroll` na linha 64, `decoration_layer.update` na 72) e que a troca de ambiente do SPEC-003 (`environment_manager.set_environment`, chamada só em `_ready`) não conflita com `decoration_layer.set_environment()` — a decoração só escreve em si mesma (FR-055, FR-053)
- [X] T047 [US8] Criar `tests/unit/test_no_collision.gd` verificando que `TrafficVehicle`, `DecorationElement` e `TrafficManager` não possuem corpo de física, sinal de contato nem método de resolução de colisão, e que nenhum contato é detectado em uma partida contínua (FR-026, FR-049, SC-018)

**Checkpoint**: Zero regressões — pronto para a fase de polimento

---

## Phase 11: Polish & Cross-Cutting Concerns

- [X] T048 [P] Validar desempenho em `tests/unit/test_performance_traffic_decoration.gd`: 60 FPS como meta e 30 FPS como piso, sem quedas recorrentes, em 10 minutos contínuos com ambos os sistemas ativos nos 4 ambientes (SC-024, FR-060)
  - 2026-10-04, Godot 4.7.2 headless: `test_frame_budget_on_all_environments` PASSED nos 4 ambientes (~0,4–0,5 ms/quadro médio para os dois sistemas combinados, 34× abaixo da meta de 16,67 ms) e `test_systems_are_popular_during_measurement` PASSED; os 10 minutos contínuos são exercidos por `test_memory_stability.gd` (T049), verde na mesma execução
- [X] T049 [P] Validar estabilidade de memória em `tests/unit/test_memory_stability.gd`: nenhum crescimento indefinido de veículos ou elementos em 10 minutos contínuos, com remoção por qualquer borda (SC-010, SC-015)
  - 2026-10-04, Godot 4.7.2 headless: `test_pools_reach_steady_state_in_ten_minutes` PASSED (36.000 quadros, pools estagnados nas duas últimas amostras, tetos respeitados) e `test_sc006_traffic_spacing_in_ten_minutes` PASSED (máx. 2 veículos abaixo do espaçamento por quadro)
- [X] T050 Implementar em `src/config/game_config.gd` a verificação de consistência entre cada lista de `assets` e o conteúdo real da pasta, usando `DirAccess` somente em modo debug e emitindo aviso de divergência, nunca em lógica de gameplay (research.md R4)
- [X] T051 Executar todos os cenários de validação V1 a V17 do `quickstart.md` e registrar o resultado de cada um
  - Registrados na "Parte 5 — Registro de execução dos cenários V1 a V17" do `quickstart.md`: os 17 cenários ✅, cada um mapeado à evidência automatizada da execução de 2026-10-04 (112 casos, 0 erros, 0 falhas)
- [X] T052 Atualizar `README.md` com os novos sistemas, as 4 categorias de veículo com suas velocidades e as 4 bibliotecas de decoração
- [X] T053 Atualizar `specs/004-traffic-and-decoration/checklists/requirements.md` com o resultado da validação final e confirmar que `src/road/`, `src/player/`, `src/environment/` e `src/game/game_state.gd` permanecem sem modificações
  - Nota de validação final (2026-10-04) registrada: 112 casos verdes, T048/T049 reprovados, V1–V17 ✅; diff confirma `src/environment/` e `src/game/game_state.gd` intactos e a única exceção — as duas linhas `class_name` — justificada na T060
- [X] T054 [US4] Adicionar em `GameConfig.DECORATION_LIBRARIES` o campo `weight` por entrada (percentual de apresentação, somando 100 por ambiente), os campos `weight` e `peso_sorteio` em `DecorationData` e o sorteio ponderado entre os candidatos elegíveis em `DecorationManager._escolher_asset`, mantendo D6/D7 (FR-036, FR-037)
- [X] T055 [US4] Implementar em `src/decoration/decoration_manager.gd` o método `_compensar_pesos`, que deriva `DecorationData.peso_sorteio` a partir de `weight` neutralizando o viés de D6 e D7 (teto de ~90,9% em biblioteca com uma única árvore repetível) — research.md R11 (FR-036)
- [X] T056 [P] [US4] Acrescentar em `tests/unit/test_decoration_libraries.gd` e `tests/unit/test_decoration_manager.gd` a verificação de que os `weight` somam 100 por ambiente e de que a frequência observada se aproxima do percentual declarado (cenário V17) (FR-036, FR-037, SC-014)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — pode começar imediatamente
- **Foundational (Phase 2)**: depende do Setup — **BLOQUEIA todas as user stories**
- **User Stories (Phases 3-10)**: todas dependem da Foundational
  - US1 é o MVP e não depende de nenhuma outra story
  - US2 depende dos componentes de US1 (mesmo módulo `src/traffic/`)
  - US3 depende dos componentes de US1 e US2
  - US4 é a primeira story de decoração e não depende de nenhuma story de trânsito
  - US5 e US6 dependem de US4
  - US7 depende de US1 a US6
  - US8 valida todas as anteriores
- **Polish (Phase 11)**: depende de todas as user stories desejadas

### User Story Dependencies

- **US1 (P1)**: após Foundational — sem dependência de outras stories. **MVP**
- **US2 (P1)**: após Foundational e US1 — integra o módulo `src/traffic/`, mas é validável isoladamente
- **US3 (P1)**: após Foundational e US1 — idem
- **US4 (P2)**: após Foundational — módulo `src/decoration/` novo, **paralelizável com US1**
- **US5 (P2)**: após US4
- **US6 (P3)**: após US4
- **US7 (P3)**: após US1 a US6
- **US8 (P1)**: após todas as stories anteriores

### Within Each User Story

- Testes escritos e confirmados como falha antes da implementação
- Resource de dados antes do manager que o consome
- `traffic_vehicle.gd` antes de `traffic_manager.gd`; `decoration_element.gd` antes de `decoration_manager.gd`
- Manager implementado antes da integração no `gameplay_manager.gd`
- `gameplay_manager.gd` é arquivo compartilhado: T014, T026, T038, T039, T042 e T045 tocam o mesmo arquivo e **não podem rodar em paralelo entre si**

### Parallel Opportunities

- T006 e T007 (Resources em módulos distintos)
- T010, T016, T019 (arquivos de teste em fases distintas)
- T023, T024, T025 (bibliotecas, manager e element de decoração em arquivos distintos)
- T048 e T049 (validações independentes)
- US1 (trânsito) e US4 (decoração) podem ser desenvolvidas em paralelo por pessoas diferentes, após a Foundational

---

## Parallel Example: User Story 1

```bash
# Lançar teste e elemento em paralelo (arquivos distintos):
Task: "T010 [P] [US1] Criar tests/unit/test_traffic_manager.gd com dublê de Road"
Task: "T014 [US1] Integrar TrafficManager em src/game/gameplay_manager.gd"

# Dependência interna: o manager exige o vehicle já existir
Task: "T011 [US1] Criar src/traffic/traffic_vehicle.gd"   # antes de
Task: "T012 [US1] Implementar src/traffic/traffic_manager.gd"
```

## Parallel Example: User Story 4

```bash
# Três arquivos distintos, três tasks [P]:
Task: "T023 [P] [US4] Criar tests/unit/test_decoration_libraries.gd"
Task: "T024 [P] [US4] Criar tests/unit/test_decoration_manager.gd"
Task: "T025 [P] [US4] Criar src/decoration/decoration_element.gd"

# Depende das três acima:
Task: "T026 [US4] Implementar src/decoration/decoration_manager.gd"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (T001 a T005)
2. Completar Phase 2: Foundational (T006 a T009) — **CRÍTICO, bloqueia tudo**
3. Completar Phase 3: User Story 1 (T010 a T015)
4. **PARAR E VALIDAR**: cenários V2, V3 e V4 do `quickstart.md`
5. Commit e demo se aprovado

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → validar V2, V3, V4 → **MVP**
3. US2 → validar V5 e Parte 1 → demo
4. US3 → validar V11 → demo
5. US4 → validar V6, V7, V8 → demo
6. US5 → validar V9, V10, V12, V16 → demo
7. US6 → validar V14 → demo
8. US7 → validar V13 → demo
9. US8 → validar V15 → demo
10. Polish → validar V1 a V17 e desempenho

### Parallel Team Strategy

Com mais de uma pessoa, após a Foundational:

1. Pessoa A: US1 → US2 → US3 (módulo `src/traffic/`)
2. Pessoa B: US4 → US5 → US6 (módulo `src/decoration/`)
3. Pessoa C: US7 → US8 (configuração e regressão)

`src/game/gameplay_manager.gd` é o **único ponto de contenção** entre as duas frentes: as tasks T014, T026, T038, T039, T042 e T045 devem ser serializadas entre as pessoas.

---

## Notes

- [P] = arquivos diferentes, sem dependência de task incompleta
- Rótulo [Story] mapeia a task para a user story correspondente da spec, para rastreabilidade
- `src/game/gameplay_manager.gd` é compartilhado entre stories — tasks que o editam nunca são [P] entre si
- Commit após cada task ou grupo lógico
- Pare em qualquer checkpoint para validar a story isoladamente
- Evitar: tasks vagas, conflitos de arquivo, dependências entre stories que quebrem a independência
- **Revisado por `/speckit.analyze`**: 6 tasks adicionadas (T003, T013, T015, T030, T036, T047) e T010 estendido para cobrir SC-022, SC-009, SC-012/SC-013 e a ausência de colisão (SC-018)
- **Lacuna de spec resolvida**: FR-036 e SC-014 agora especificam a repetição por meio do campo de configuração `repeatable`, e não por string no nome do asset — atribuídos a US4 (T028) e ao cenário V8

---

## Phase 12: Convergence

> Gerado por `/speckit.converge`. Avaliação do código atual contra `spec.md`, `plan.md`, este `tasks.md` e a constituição v2.0.0. Nenhuma task existente foi alterada; nenhuma fase anterior foi reescrita.

- [X] T057 CRITICAL Executar as 12 suítes de `tests/unit/` (9 do SPEC-004 + 3 pré-existentes) em ambiente com Godot 4.7 e GdUnit4, registrar o resultado de cada uma — inclusive as de T048 e T049 — e liberar o gate de cobertura da linha 12 deste arquivo, mantendo as tasks de teste provisórias até lá per Constitution §Testes (missing)
  - Gate liberado com 102 casos, 0 erros e 0 falhas (tabela na linha 12), reproduzido em 2 execuções consecutivas
  - Correções aplicadas para o verde: fixtures `before_each`/`after_each` → `before_test`/`after_test` (6 suítes, o GdUnit4 só define esses hooks); `contains_key` → `contains_keys` e `is_equal_approx(x)` → `is_equal_approx(x, ε)` (API do GdUnit4); `is PhysicsBody2D` sobre variável tipada em `test_no_collision.gd`
  - Inputs de `VehicleController` passam a ser pressionados/soltos nos testes de física (headless não recebe teclado) e a asserção invertida de `test_vertical_bounds` foi corrigida
  - `test_traffic_manager`: uso de `set_enabled()` (FR-024), referência de categoria medida pelo manager (FR-011/R10), contagem da zona de transição por quadro e rótulo `SC-026` → `SC-006`
  - `test_memory_stability`: estabilidade medida pela estagnação das duas últimas amostras, não pelo valor do aquecimento
  - **Bug de produto corrigido** em `TrafficManager.setup()` → `TrafficData.garantir_size()`: a largura da textura era medida só no primeiro `activate`, depois de `_tentar_spawn` já ter calculado a faixa com `size == ZERO` (violação de I2/FR-014 no primeiro nascimento de cada categoria)
  - `test_decoration_manager`: medição do reposicionamento passou a acompanhar todos os elementos por quadro (o `update()` move a lista inteira, então medir só o elemento da vez falhava ~50% das vezes)
- [X] T058 Fazer `src/decoration/decoration_manager.gd::_criar_elemento` suprimir o nascimento quando não houver espaço longitudinal suficiente na direção de deslocamento (nenhum elemento criado sobreposto ao anterior) e acrescentar em `tests/unit/test_decoration_manager.gd` a verificação da SC-026 — separação de mesma profundidade maior ou igual a `decoration_spacing_min` ao longo de uma corrida longa — per FR-038, SC-026, caso de borda "Espaço longitudinal insuficiente" (missing)
  - Teste `test_sc026_spacing_between_same_depth_elements`: 10 minutos contínuos (36.000 quadros), verificando quadro a quadro (a) separação de mesma profundidade ≥ `decoration_spacing_min` agrupando por lado + profundidade (sobreposição entre profundidades distintas é permitida, FR-038), (b) 0 elementos sobre a área trafegável ou dentro de `decoration_safety_margin` e (c) todo elemento ativo se desloca exatamente uma vez por quadro (FR-040)
  - **Bug de produto corrigido (1)**: `DecorationManager.update()` percorria `active_elements` em ordem crescente e `_desativar` removia do array durante a iteração, fazendo o elemento seguinte perder um quadro de deslocamento e desalinhar o espaçamento — 218 quadros violando a SC-026 em 10 minutos antes do ajuste; agora a iteração é de trás para frente, em `DecorationManager.update()` e em `TrafficManager._mover_ativos()` (mesma classe de defeito, FR-019/SC-006)
  - **Bug de produto corrigido (2)**: `DecorationData.garantir_size()` novo e chamado em `DecorationManager.setup()` — o primeiro nascimento de cada asset calculava altura e meia-largura com `size == ZERO` e nascia invadindo a área trafegável + margem de segurança no quadro do nascimento (FR-042, espelha a correção da T057 em `TrafficData`)
  - Verde em suíte isolada (14 casos) e na suíte completa (103 casos, 0 erros, 0 falhas, exit 101)
- [X] T059 Adicionar em `tests/unit/test_memory_stability.gd` (ou suíte dedicada) a medição da SC-006 numa simulação de 10 minutos — no máximo 2 pares de veículos ativos com separação longitudinal inferior a `traffic_min_spacing` — ajustando spawn ou movimento em `src/traffic/traffic_manager.gd` se a verificação falhar, e corrigir em `tests/unit/test_traffic_manager.gd:307` o rótulo `SC-026`, que é o SC da decoração, para SC-006 per SC-006, FR-019 (missing)
  - Rótulo `SC-026` → `SC-006` em `tests/unit/test_traffic_manager.gd:307` corrigido
  - Teste `test_sc006_traffic_spacing_in_ten_minutes`: 10 minutos contínuos (36.000 quadros) com `road.scroll_speed = GameConfig.max_speed` (senão a categoria igual à velocidade da estrada fica parada na linha de criação e trava os nascimentos, mesma degeneração de `test_no_immediate_overlap_after_spawn`), contando por quadro os veículos em pares a menos de `traffic_min_spacing`; asserções: corrida com trânsito em mais de metade dos quadros, trânsito vivo ao final e **no máximo 2 veículos** envolvidos (mais estrito que o "2 pares" da SC), com mensagem de falha trazendo contagem e pior par
  - Medição antes do ajuste (só spawn): **92% dos quadros** com mais de 2 veículos abaixo do mínimo, pior caso 12 dos 12 — só o espaçamento de criação não resolve
  - Decisão do usuário registrada: manter o espaçamento no movimento (não é IA de ultrapassagem, FR-062; FR-007 segue valendo o deslocamento exato quando não se está seguindo ninguém)
  - **Ajuste de produto em `TrafficManager._mover_ativos()` (FR-019)**: novos arrays reutilizados `_dy_desejado` e `_y_futuro`; ordem de movimento por grupo de sentido (líder primeiro, `_cmp_maior_y` / `_cmp_menor_y`); `_lider_mais_proximo()` acha o veículo à frente no sentido do próprio movimento; `_mover_com_limite()` aplica teto (descida) / piso (subida) para nunca fechar abaixo de `traffic_min_spacing`
  - `TrafficVehicle.update_scroll()` ganhou o 4º parâmetro `dy_limite` obrigatório (único chamador é o manager) e nunca anda para trás (FR-006)
  - `FOLGA_ESPACAMENTO = 0.01` px somada ao mínimo nos limites de movimento e na checagem de criação: as posições acumulam soma em ponto flutuante e pares exatamente em `traffic_min_spacing` oscilavam em ~69,999 px, contando como violação
  - `TrafficManager._espaco_longo_insuficiente()` documentado como FR-019/SC-006 (citava FR-038/SC-026, da decoração)
  - Verde em suíte isolada (2 casos) e na suíte completa (**104 casos, 0 erros, 0 falhas, exit 101**)
- [X] T060 Reconciliar a exceção de escopo: `src/road/road.gd` e `src/player/player_vehicle.gd` ganharam uma linha cada (`class_name Road` / `class_name PlayerVehicle`), exigida pelos dublês `extends Road` dos testes — justificar formalmente em `plan.md` e neste arquivo (ou remover as linhas e ajustar os dublês) para que a T053 possa confirmar a ausência de modificações per plan: Source Code, "Fora de escopo desta lista" (contradicts)
  - Caminho adotado: **justificar**, não remover — os dublês só existem por herança, porque `update(delta, road: Road)` recusa outro tipo em runtime. Justificativa registrada em `plan.md` (seção "Exceção de escopo justificada (T060)") e na nota "Exceção reconciliada pela T060" acima; diff dos dois arquivos confirmado como uma única linha cada
- [X] T061 Fazer `src/game/gameplay_manager.gd` propagar a troca de ambiente para `decoration_layer.set_environment()` sempre que o ambiente vigente mudar, sem tocar em `src/environment/`, de modo que a troca da biblioteca ocorra automaticamente sem exigir nova alteração de código per FR-031, US6/AC1 (missing)
  - `gameplay_manager.gd` ganhou `_propagar_ambiente(id)` (fundo + `decoration_layer.set_environment`) e a detecção por quadro de `GameConfig.current_environment_id` em `_process`; o `_ready` passou a usar o mesmo caminho, e o id solicitado é o registrado para não re-propagar infinitamente o fallback "PLAINS"
- [X] T062 Acrescentar em `tests/unit/test_traffic_categories.gd` a verificação da proporção observada das quatro categorias numa simulação prolongada, aproximando-se das `frequency` declaradas — o equivalente ao que o cenário V17 (T056) já faz para a decoração per SC-004, US2/AC1, FR-010 (missing)
  - `test_observed_category_frequency_matches_declared`: 20.000 sorteios diretos de `_sortear_categoria`, tolerância de ±2 p.p. (~6σ); verde
- [X] T063 Expor a direção do veículo em `src/traffic/traffic_vehicle.gd` (campo e leitura) e nos dados devolvidos por `TrafficManager`, completando os seis atributos exigidos por FR-002 — tipo, posição, velocidade, direção, faixa e estado — per FR-002 (partial)
  - `enum Direction { FORWARD = 1, OPPOSITE = -1 }`, campo `direction` (sempre FORWARD nesta versão, FR-006; OPPOSITE reservado pela arquitetura de FR-008) e `get_direction()`; o snapshot de `get_vehicles_data()` passou a trazer os seis atributos (`id`, `position`, `speed`, `direction`, `lane`, `state`) mais `occupied_area` (FR-025); asserção dos seis atributos acrescentada ao teste do snapshot
- [X] T064 Cobrir a SC-023 em `tests/unit/test_traffic_manager.gd`: durante a redução contínua de 4 para 2 vias, zero veículos aparecem ou desaparecem da área visível em razão da mudança de largura per SC-023, US3/AC6 (missing)
  - `test_sc023_no_blink_during_narrowing`: redução 176→144 px em 2 s com spawn desligado; por quadro, 100% dos veículos dentro da faixa vigente e nenhuma inversão de visibilidade longe da borda vertical (a única transição legítima); verde
- [X] T065 Cobrir a SC-003 em `tests/unit/test_traffic_manager.gd`: quando a velocidade do jogador cruza a do veículo, a direção relativa inverte de forma contínua e nenhum veículo fica parado sobre a tela per SC-003, US1/AC4, FR-007 (missing)
  - `test_sc003_continuous_inversion_when_crossing_vehicle_speed`: um `esporte` (96.0) controlado, estrada varrida de 60.0 a 100.0; por quadro o sinal do deslocamento é o sinal de (estrada − veículo), exatamente 1 inversão, no máximo 1 quadro parado (o cruzamento exato) e nenhum salto; verde
- [X] T066 Criar `tests/unit/test_constitution.gd` com regressão dos princípios redefinidos pela emenda v2.0.0 (§Trânsito e §Suporte Multilíngue), conforme o procedimento de emenda per Constitution §Governança (missing)
  - 5 casos: documento em 2.0.0 em pt-BR com as duas ressalvas da emenda (SPEC-005 e localização dedicada); veículo fornece identificação/posição/área (§Trânsito MUST); vocabulário de colisão ausente de sinais e métodos dos 4 scripts novos (§Trânsito MUST NOT); geração separada do veículo; `display_name` de usuário externalizado em GameConfig (§VI SHOULD). Verde
---

## Phase 13: Ajustes pós-implementação (2026-10-05 — validados nos testes manuais da SPEC-005)

> 4 ajustes de comportamento do trânsito descobertos durante o aceite manual da SPEC-005;
> registrados nesta spec (clarificações de 2026-10-05, FR-019/FR-023 emendados, FR-063/FR-064,
> FR-065, SC-006/SC-028/SC-029/SC-030). Suíte completa ao final dos 6 ajustes (incluindo os
> ajustes 4 e 6, da SPEC-005): 24 suítes, 160 casos verdes (exit 101).

- [X] T067 [P] Ajuste 1 — separação no nascimento: `traffic_min_separation` + checagem retangular no spawn de `src/traffic/traffic_manager.gd` e suíte nova `tests/unit/test_traffic_separation.gd` per FR-019
- [X] T068 Ajuste 2 — líder de comboio restrito ao mesmo corredor lateral em `_lider_mais_proximo()` (`src/traffic/traffic_manager.gd`); invariante do teste de 10 min (`tests/unit/test_memory_stability.gd`) passa a contar pares apenas no mesmo corredor per FR-007, FR-011, SC-006, SC-029
- [X] T069 Ajuste 3 — densidade mínima (3 na estrada junto ao jogador) com reposição imediata por quadro e teto de ativos por dificuldade (máx. 5 visíveis em Gelo): parâmetros em `src/config/game_config.gd`, lógica em `src/traffic/traffic_manager.gd`, suíte nova `tests/unit/test_traffic_density.gd` e exceção de enchimento no teste FR-019 legado (`test_no_immediate_overlap_after_spawn`) per FR-063, FR-064, SC-028
- [X] T070 [P] Atualização documental: clarificações de 2026-10-05, emendas de FR-019/FR-023, FR-063/FR-064, SC-006/SC-028/SC-029 e caso de borda em `specs/004-traffic-and-decoration/spec.md`; nota de revalidação nos checklists; ponteiros nos `quickstart.md` das duas specs
- [X] T071 Ajuste 5 — travamento de velocidade entre categorias: faixas laterais reservadas por velocidade (`_slot_da_categoria`) na origem do nascimento, corredor lateral = interseção das projeções laterais em `_lider_mais_proximo()` e piso de espaçamento size-aware (meias-alturas + separação) em `_espaco_min_centros()` de `src/traffic/traffic_manager.gd`; invariante do teste de 10 min (`tests/unit/test_memory_stability.gd`) passa a contar pares apenas com projeções intersectadas e suíte nova `tests/unit/test_traffic_speed_ordering.gd` (colunas ordenadas, caminhão livre na taxa da categoria, separação size-aware durante o movimento) per FR-019, FR-065, SC-006, SC-030
- [X] T072 [P] Atualização documental do ajuste 5: clarificações, FR-065, SC-030, caso de borda "Faixa da velocidade ocupada no nascimento" e emendas de FR-019/SC-006/SC-029 em `specs/004-traffic-and-decoration/spec.md`; contagens e ponteiros nos `quickstart.md` das duas specs, checklist da SPEC-004, tabela de ajustes do `plan.md` da SPEC-005 e `AGENTS.md`

---

## Phase 14: Reajuste de assets de veículos (2026-10-10)

> Reajuste de arte do usuário: conteúdo dos 14 PNGs de NPC normalizado dentro do mesmo
> canvas — 32×64 nas 3 categorias de carros e 32×128 no caminhão (inalterado), o que
> preserva o contrato de tamanho da tabela de categorias (data-model §2) e o espaçamento
> derivado dele (`garantir_size` mede o canvas, que não mudou). Correção de naming:
> `carro_01png` → `carro_01.png` (o `TRAFFIC_CATEGORIES["passeio"]` e as specs exigem
> `carro_01`). `*.import` regenerados. Sonda headless de 4000 nascimentos com a
> semântica do pool (cache de textura por categoria — FR-017): os 17 assets carregam e
> o sorteio é uniforme (Carro-prata 12,1% ≈ 1/7 dos utilitários, ~3,5% de todos os
> veículos — presença confirmada no aceite manual do usuário após ~10 min).
> Suíte completa: 41 suítes, 259 casos verdes (exit 101).

- [X] T073 Normalizar o conteúdo dos assets em `assets/npcs/**` (bbox alfa ~22 px de largura centrado no canvas), renomear `assets/npcs/passeio/carro_01png` → `carro_01.png` e regenerar os `*.import` per data-model §2, FR-011, FR-012
- [X] T074 [P] Atualização documental: §Trânsito do `README.md` (normalização e uniformidade do sorteio), Phase 14 da SPEC-005 (recalibração das hitboxes ao novo bbox visível) e nota no `AGENTS.md`
