# Contrato: APIs Consumidas da SPEC-001 a SPEC-007 (SPEC-008)

A SPEC-008 consome os sistemas existentes **somente por leitura ou por chamadas já públicas**; nenhuma assinatura existente muda de significado. Alterações aditivas estão marcadas.

---

## 1. `GameState` (`src/game/game_state.gd` — SPEC-001)

| Item | Uso |
|---|---|
| `State.*` / `current_state` / `state_changed` | leitura e observação |
| `start_game() / begin_playing() / pause_game() / resume_game()` | já usados pelo `GameplayManager` |
| `victory() / game_over()` | **passam a ser chamados** pelo `GameplayManager` (existiam sem uso — janela 007→008 fechada) |
| `reset()` | retorno ao menu |

## 2. `FuelSystem` (`src/fuel/fuel_system.gd` — SPEC-007)

| Item | Uso |
|---|---|
| `reset() / update(delta, velocidade) / get_atual() / get_capacidade() / esta_baixo()` | inalterados |
| sinais `fuel_changed / fuel_low / fuel_depleted` | HUD inalterado; `fuel_depleted` continua só avisando (transição é daqui) |
| **+** `definir_capacidade_derivada(cap)` | NOVO (contrato `fuel_restoration.md`) |
| **+** `restaurar(valor)` | NOVO (contrato `fuel_restoration.md`) |

## 3. `PlayerVehicle` / `VehicleController` (SPEC-001/005)

| Item | Uso |
|---|---|
| `get_speed()` | fonte de rolagem, consumo, progressão e geração (única velocidade de avanço) |
| `change_sprite(path)` | seleção do menu (`GameConfig.default_sprite_path`/`alt_sprite_path`) |
| `controller.aceleracao_bloqueada` (SPEC-005) | intocada; convive com a flag nova de combustível |
| **+** `controller.aceleracao_bloqueada_por_combustivel` | NOVO, escrito pelo `GameplayManager`, checado na física vertical |
| **+** `reset()` em `PlayerVehicle` | NOVO (delega ao `controller.reset()` existente + posição/sprite) |

## 4. `Road` (SPEC-002)

| Item | Uso |
|---|---|
| `scroll_speed` / `update_scroll_speed(v)` | rolagem + freeze em pausa (`0.0`) |
| `left_boundary` / `right_boundary` / `get_boundaries_for_player_y(y)` | posicionamento válido de galões e marcadores |
| sinais `segment_type_changed` / `boundary_changed` | inalterados (SPEC-006) |
| **+** `reset()` | NOVO (`scroll_speed/scroll_offset` zerados, tipos reiniciados) |

## 5. `TrafficManager` / `CollisionSystem` / `NpcCollisionSystem` / `DecorationManager` (SPEC-004–006)

| Item | Uso |
|---|---|
| `active_vehicles_snapshot` | leitura pelo `FuelCanManager` para evitar NPCs na validação de spawn |
| **+** `reset()` em cada um | NOVO, aditivo, chamado apenas pela orquestração de nova corrida (SC-012) |

## 6. `GameConfig` (autoload)

| Item | Uso |
|---|---|
| `max_speed`, `KMH_TO_SPEED_UNIT`, `ENVIRONMENTS`, `current_environment_id` | leitura |
| `fuel_*` (SPEC-007) | leitura (fórmula + limites) |
| `default_sprite_path` / `alt_sprite_path` | seleção de veículo |
| **+** bloco `## Progressão e Itens (SPEC-008)` | NOVO (data-model §6) |

## 7. `FuelHud` (SPEC-007)

INALTERADO — continua observando `fuel_changed`/`esta_baixo()`; o `UIManager` não o substitui nem o duplica.
