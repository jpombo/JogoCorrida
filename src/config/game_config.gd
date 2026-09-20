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

## Limites da estrada (pista de 2 vias centralizada — largura 144px, centro 320)
@export var road_left_boundary: float = 248.0
@export var road_right_boundary: float = 392.0

## Performance
@export var target_fps: int = 60

## Assets
@export var default_sprite_path: String = "res://assets/player/azul/azul.png"
@export var alt_sprite_path: String = "res://assets/player/vermelho/vermelho.png"

## Scrolling da estrada
@export var scroll_multiplier: float = 1.0  # Fator entre velocidade do jogador e scrolling
@export var visible_segment_count: int = 0  # Quantidade de segmentos (0 = cálculo automático)
@export var segment_buffer: int = 2  # Segmentos extras além dos visíveis
@export var segment_spacing: float = 0.0  # Espaçamento entre segmentos (0 = sem espaço)
@export var road_straight_path: String = "res://assets/estrada/estrada_2_vias.png"
@export var road_expansion_path: String = "res://assets/estrada/estrada_expansao_4_vias.png"
@export var road_expanded_2_lanes_path: String = "res://assets/estrada/estrada_2_vias_expandido.png"
@export var road_reduction_path: String = "res://assets/estrada/estrada_reducao_2_vias.png"

## Sequência de teste da pista (tipos: 0=STRAIGHT, 1=EXPANSION, 2=REDUCTION, 3=EXPANDED_2_LANES)
## Formato: [tipo, quantidade]
@export var test_track_sequence: Array = [
	[0, 10],  # 10 segmentos retos (2 vias)
	[1, 1],   # 1 segmento de expansão (2→4 vias)
	[3, 10],  # 10 segmentos expandidos (2 vias expandidas)
	[2, 1],   # 1 segmento de redução (4→2 vias)
]
