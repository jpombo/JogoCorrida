class_name VehicleController
extends RefCounted

## Velocidade atual do veículo
var speed: float = 0.0

## Velocidade lateral atual
var lateral_speed: float = 0.0

## Delta do frame atual
var current_delta: float = 0.0

## Limites laterais atuais da estrada
var current_left_boundary: float = 248.0
var current_right_boundary: float = 392.0

## Se o veículo está em movimento
var is_moving: bool:
	get:
		return speed > 0.0

## Signals
signal speed_changed(new_speed: float)
signal position_changed(new_position: Vector2)
signal boundary_reached(side: String)

## Processar inputs e atualizar física
func _process(delta: float) -> void:
	current_delta = delta
	_apply_vertical_physics(delta)
	_apply_lateral_physics(delta)
	speed_changed.emit(speed)

## Calcular física vertical (aceleração, frenagem, inércia)
func _apply_vertical_physics(delta: float) -> void:
	if Input.is_action_pressed("accelerate") and not Input.is_action_pressed("brake"):
		speed = min(speed + GameConfig.acceleration * delta, GameConfig.max_speed)
	elif Input.is_action_pressed("brake"):
		speed = max(speed - GameConfig.brake_force * delta, 0.0)
	else:
		speed = max(speed - GameConfig.natural_deceleration * delta, 0.0)

## Calcular física lateral (independente do vertical)
func _apply_lateral_physics(delta: float) -> void:
	if Input.is_action_pressed("move_left"):
		lateral_speed = max(lateral_speed - GameConfig.lateral_acceleration * delta, -GameConfig.lateral_speed)
	elif Input.is_action_pressed("move_right"):
		lateral_speed = min(lateral_speed + GameConfig.lateral_acceleration * delta, GameConfig.lateral_speed)
	else:
		if lateral_speed > 0:
			lateral_speed = max(lateral_speed - GameConfig.lateral_deceleration * delta, 0.0)
		else:
			lateral_speed = min(lateral_speed + GameConfig.lateral_deceleration * delta, 0.0)

## Retornar posição Y normalizada baseada na velocidade
func get_vertical_position() -> float:
	var speed_ratio: float = speed / GameConfig.max_speed
	return lerp(GameConfig.vertical_position_max, GameConfig.vertical_position_min, speed_ratio)

## Retornar direção lateral (-1.0, 0.0, ou 1.0)
func get_horizontal_direction() -> float:
	if lateral_speed < -0.1:
		return -1.0
	elif lateral_speed > 0.1:
		return 1.0
	return 0.0

## Respeitar limites da estrada (considerando metade da largura do carro)
func _clamp_position(current_x: float) -> float:
	var old_x = current_x
	var half_width = 16.0  # Metade da largura do sprite (32px)
	var min_x = current_left_boundary + half_width
	var max_x = current_right_boundary - half_width
	
	# Se o carro está fora dos novos limites, mover suavemente para dentro
	if current_x < min_x:
		current_x = min(current_x + 200.0 * current_delta, min_x)
	elif current_x > max_x:
		current_x = max(current_x - 200.0 * current_delta, max_x)
	
	if current_x != old_x:
		var side = "left" if current_x < old_x else "right"
		boundary_reached.emit(side)
	
	return current_x

## Atualizar limites da estrada (chamado quando a pista muda de tipo)
func update_boundaries(left: float, right: float) -> void:
	current_left_boundary = left
	current_right_boundary = right

## Resetar estado para valores iniciais
func reset() -> void:
	speed = 0.0
	lateral_speed = 0.0
	current_left_boundary = GameConfig.road_left_boundary
	current_right_boundary = GameConfig.road_right_boundary
