extends Node

## Parâmetros de física do veículo
@export var max_speed: float = 100.0
@export var acceleration: float = 40.0
@export var brake_force: float = 70.0
@export var natural_deceleration: float = 15.0

## Parâmetros de movimento lateral
@export var lateral_speed: float = 100.0
@export var lateral_acceleration: float = 300.0
@export var lateral_deceleration: float = 400.0

## Posição vertical
@export var initial_vertical_position: float = 0.95  # Inicia quase na base (com margem)
@export var vertical_position_min: float = 0.6  # Topo: 1 tamanho do carro abaixo do meio (288/480)
@export var vertical_position_max: float = 0.95  # Base: com margem para o sprite completo

## Limites da estrada
@export var road_left_boundary: float = 100.0
@export var road_right_boundary: float = 540.0

## Performance
@export var target_fps: int = 60

## Assets
@export var default_sprite_path: String = "res://assets/player/azul/azul.png"
@export var alt_sprite_path: String = "res://assets/player/vermelho/vermelho.png"
