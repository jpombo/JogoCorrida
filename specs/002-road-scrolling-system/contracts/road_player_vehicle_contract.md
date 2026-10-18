# Contract: Road ↔ PlayerVehicle Interface

**Feature**: 002-road-scrolling-system
**Date**: 2026-09-18

## Overview

Este contrato define a interface entre Road e PlayerVehicle para o sistema de scrolling e sincronização de limites.

## Interface

### Road → PlayerVehicle (Leitura)

Road precisa ler a velocidade atual do jogador para calcular o scrolling.

```text
Propriedade requerida:
    speed: float  # Velocidade atual do veículo (0.0 a max_speed)

Método alternativo (se propriedade não disponível):
    get_speed() -> float
```

**Uso**:
```text
road_scroll_speed = player_vehicle.speed × scroll_multiplier
```

### PlayerVehicle → Road (Escrita)

PlayerVehicle NÃO deve escrever diretamente no Road.

**Proibido**:
```text
road.scroll_speed = x  # NÃO PERMITIDO
road.position.y = x    # NÃO PERMITIDO
```

### Road → VehicleController (Sincronização de Limites)

Road calcula limites dinamicamente baseado na posição Y do jogador, e gameplay_manager atualiza VehicleController.

```text
Método:
    get_boundaries_for_player_y(player_y: float) -> Dictionary
    Retorna: {"left": float, "right": float}

Chamada (via gameplay_manager a cada frame):
    var boundaries = road.get_boundaries_for_player_y(player_vehicle.position.y)
    player_vehicle.controller.update_boundaries(boundaries.left, boundaries.right)

Resultado:
    VehicleController.current_left_boundary = left
    VehicleController.current_right_boundary = right
```

### Road → GameConfig (Leitura)

Road lê parâmetros configuráveis de GameConfig.

```text
Parâmetros requeridos:
    scroll_multiplier: float
    road_left_boundary: float
    road_right_boundary: float
    road_straight_path: String
    road_expansion_path: String
    road_expanded_2_lanes_path: String
    road_reduction_path: String
    segment_buffer: int
    segment_spacing: float
    visible_segment_count: int
```

## Signals

### Road Signals

```text
signal segment_type_changed(new_type: int)
    # Emitido quando o segmento atual muda de tipo
    # Tipos: 0=STRAIGHT, 1=EXPANSION, 2=REDUCTION, 3=EXPANDED_2_LANES

signal boundary_changed(left: float, right: float)
    # Emitido quando limites laterais mudam (após _update_boundaries)
    # NOTA: Não é mais usado para sincronizar com VehicleController
    # Limites são calculados dinamicamente via get_boundaries_for_player_y()
```

### PlayerVehicle Signals (existentes do SPEC-001)

```text
signal speed_changed(new_speed: float)
    # Já existe - usado por Road para calcular scrolling
```

## Validação

### Compile-time

- Road deve ter método get_boundaries_for_player_y()
- GameConfig deve ter todos os parâmetros requeridos
- gameplay_manager deve chamar road.get_boundaries_for_player_y() a cada frame

### Runtime

- scroll_speed deve ser ≥ 0
- segment_pool deve ter pelo menos 1 elemento
- left_boundary < right_boundary
- VehicleController.current_left_boundary deve ser atualizado quando gameplay_manager chama get_boundaries_for_player_y()
- Para EXPANSION: right boundary interpola de narrow_right (392) para wide_right (424)
- Para REDUCTION: right boundary interpola de wide_right (424) para narrow_right (392)

## Exemplo de Uso

```text
# No gameplay_manager.gd
func _ready():
    game_state.reset()

func _process(delta):
    if game_state.current_state == game_state.State.PLAYING:
        if player_vehicle:
            road.update_scroll_speed(player_vehicle.get_speed())

        # Atualizar limites baseado na posicao Y do jogador
        if player_vehicle and road:
            var boundaries = road.get_boundaries_for_player_y(player_vehicle.position.y)
            player_vehicle.controller.update_boundaries(boundaries.left, boundaries.right)

# No road.gd (get_boundaries_for_player_y)
func get_boundaries_for_player_y(player_y: float) -> Dictionary:
    # Encontra segmento que contem player_y e interpola limites
    # t = 1.0 - (player_y - seg_top) / segment_height (invertido para scroll)
    # EXPANSION: lerpf(narrow_right, wide_right, t)
    # REDUCTION: lerpf(wide_right, narrow_right, t)

# No vehicle_controller.gd
func update_boundaries(left: float, right: float) -> void:
    current_left_boundary = left
    current_right_boundary = right
```
