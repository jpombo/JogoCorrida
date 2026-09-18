extends Node2D

## Limites laterais da estrada
@export var left_boundary: float = 100.0
@export var right_boundary: float = 540.0

## Limites verticais
@export var top_boundary: float = 0.0
@export var bottom_boundary: float = 480.0

## Largura calculada da estrada
var road_width: float:
	get:
		return right_boundary - left_boundary

## Offset de scrolling
var scroll_offset: float = 0.0

## Velocidade de scrolling atual
var current_scroll_speed: float = 0.0

func _ready() -> void:
	left_boundary = GameConfig.road_left_boundary
	right_boundary = GameConfig.road_right_boundary

func _process(delta: float) -> void:
	# Mover estrada para baixo conforme velocidade (cria sensação de progressão)
	if current_scroll_speed > 0:
		position.y += current_scroll_speed * delta
		scroll_offset += current_scroll_speed * delta
		
		# Resetar posição quando atinge limite (loop infinito)
		if position.y > bottom_boundary:
			position.y -= bottom_boundary

## Atualizar velocidade de scrolling (chamado pelo gameplay_manager)
func update_scroll_speed(speed: float) -> void:
	current_scroll_speed = speed

func get_left_boundary() -> float:
	return left_boundary

func get_right_boundary() -> float:
	return right_boundary

func get_road_width() -> float:
	return road_width
