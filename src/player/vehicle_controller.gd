class_name VehicleController
extends RefCounted

## Velocidade atual do veículo
var speed: float = 0.0

## Velocidade lateral atual
var lateral_speed: float = 0.0

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

## Respeitar limites da estrada
func _clamp_position(current_x: float) -> float:
	var old_x = current_x
	current_x = clamp(current_x, GameConfig.road_left_boundary, GameConfig.road_right_boundary)
	
	if current_x != old_x:
		var side = "left" if current_x < old_x else "right"
		boundary_reached.emit(side)
	
	return current_x

## Resetar estado para valores iniciais
func reset() -> void:
	speed = 0.0
	lateral_speed = 0.0
