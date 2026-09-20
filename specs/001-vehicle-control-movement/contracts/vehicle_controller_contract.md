# Interface Contract: VehicleController

**Feature**: 001-vehicle-control-movement
**Date**: 2026-09-18

## Purpose

Define a interface pública do VehicleController — como outros sistemas devem interagir com ele.

## Public Interface

### VehicleController

**Responsabilidade**: Gerenciar lógica de controle do veículo — ler inputs, calcular física, atualizar estado.

#### Signals (Eventos)

```gdscript
signal speed_changed(new_speed: float)
signal position_changed(new_position: Vector2)
signal boundary_reached(side: String)  # "left" ou "right"
```

#### Properties (Acessíveis por PlayerVehicle)

```gdscript
var speed: float                      # Velocidade atual (0 a max_speed)
var lateral_speed: float              # Velocidade lateral atual
var current_left_boundary: float      # Limite esquerdo atual da estrada
var current_right_boundary: float     # Limite direito atual da estrada
var is_moving: bool                   # Se veículo está em movimento (speed > 0)
```

#### Methods (Públicos)

```gdscript
func _process(delta: float) -> void:
    """
    Processar inputs e atualizar física. Chamar a cada frame.
    Atualiza speed, lateral_speed, e emite signals.
    """

func get_vertical_position() -> float:
    """
    Retornar posição Y normalizada (0.0 a 1.0) baseada na velocidade atual.
    Usado por PlayerVehicle para posicionar sprite.
    """

func get_horizontal_direction() -> float:
    """
    Retornar direção lateral (-1.0, 0.0, ou 1.0) baseado na velocidade lateral.
    Usado por PlayerVehicle para espelhar sprite se necessário.
    """

func _clamp_position(current_x: float) -> float:
    """
    Respeitar limites dinâmicos da estrada (considerando metade da largura do carro).
    Limites são atualizados quando a pista muda de tipo (expansão/redução).
    """

func update_boundaries(left: float, right: float) -> void:
    """
    Atualizar limites laterais da estrada.
    Chamado quando a pista muda de tipo (expansão 2→4 vias, redução 4→2 vias).
    """

func reset() -> void:
    """
    Resetar estado para valores iniciais. Usar ao iniciar nova partida.
    """
```

#### Dependencies

- **Input**: Sistema de Input Map do Godot (actions: accelerate, brake, move_left, move_right)
- **Config**: GameConfig (autoload) — leitura de parâmetros de física
- **Output**: Atualiza estado do PlayerVehicle (via composição)
- **Events**: boundary_changed signal do Road (via gameplay_manager)

## Usage Examples

### Exemplo 1: PlayerVehicle integrando VehicleController

```gdscript
# player_vehicle.gd
extends Node2D

@onready var controller = VehicleController.new()
@onready var sprite = $Sprite2D

func _process(delta):
    controller._process(delta)
    # Aplicar posição baseada no controller
    position.y = controller.get_vertical_position()
    # Aplicar limites dinâmicos
    position.x = controller._clamp_position(position.x)
```

### Exemplo 2: GameManager conectando signals de limites

```gdscript
# gameplay_manager.gd
extends Node2D

func _ready():
    # Conectar mudança de limites da estrada ao controlador
    road.boundary_changed.connect(player_vehicle.controller.update_boundaries)
```

### Exemplo 3: Atualização dinâmica de limites

```gdscript
# Quando a pista muda de tipo (2 vias → 4 vias)
road.boundary_changed.emit(new_left_boundary, new_right_boundary)
# Isso atualiza automaticamente os limites no VehicleController
```

## Constraints

1. VehicleController NÃO deve acessar diretamente o Sprite2D ou nós visuais
2. VehicleController NÃO deve decidir mudanças de GameState
3. VehicleController DEVE respeitar parâmetros do GameConfig
4. VehicleController DEVE emitir signals para mudanças de estado
5. VehicleController DEVE ser testável independentemente (sem dependência de scene tree)
6. VehicleController DEVE atualizar limites quando Road emite boundary_changed
7. Limites laterais DEVEM considerar metade da largura do carro (16px) para evitar saída visual da pista

## Testing Contract

### Unit Tests Obrigatórios

1. `test_speed_increases_with_acceleration` — Aceleração progressiva
2. `test_speed_decreases_with_brake` — Frenagem progressiva
3. `test_brake_overrides_accelerate` — Prioridade de frenagem
4. `test_natural_deceleration` — Desaceleração quando solto
5. `test_speed_clamped_at_max` — Limite superior de velocidade
6. `test_speed_clamped_at_zero` — Limite inferior de velocidade
7. `test_lateral_movement_independent` — Movimento lateral independente
8. `test_diagonal_movement` — Combinação vertical + horizontal
9. `test_boundary_collision_left` — Limite esquerdo (considerando half_width)
10. `test_boundary_collision_right` — Limite direito (considerando half_width)
11. `test_reset` — Reset para estado inicial
12. `test_update_boundaries` — Atualização de limites dinâmicos
