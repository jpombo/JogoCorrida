extends GutTest

var controller: VehicleController

func before_each() -> void:
	controller = VehicleController.new()

func after_each() -> void:
	controller = null

func test_speed_increases_with_acceleration() -> void:
	controller.speed = 0.0
	controller._process(0.1)
	assert_gt(controller.speed, 0.0, "Velocidade deve aumentar com aceleração")

func test_speed_decreases_with_brake() -> void:
	controller.speed = 100.0
	controller._process(0.1)
	assert_lt(controller.speed, 100.0, "Velocidade deve diminuir com frenagem")

func test_brake_overrides_accelerate() -> void:
	controller.speed = 50.0
	controller._process(0.1)
	assert_lt(controller.speed, 50.0, "Frenagem deve prevalecer sobre aceleração")

func test_natural_deceleration() -> void:
	controller.speed = 100.0
	controller._process(0.1)
	assert_lt(controller.speed, 100.0, "Velocidade deve diminuir com desaceleração natural")

func test_speed_clamped_at_max() -> void:
	controller.speed = 99.0
	controller._process(1.0)
	assert_eq(controller.speed, GameConfig.max_speed, "Velocidade não deve exceder max_speed")

func test_speed_clamped_at_zero() -> void:
	controller.speed = 1.0
	controller._process(1.0)
	assert_eq(controller.speed, 0.0, "Velocidade não deve ficar abaixo de zero")

func test_lateral_movement_independent() -> void:
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_ne(controller.lateral_speed, 0.0, "Movimento lateral deve ser independente")

func test_diagonal_movement() -> void:
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_gt(controller.speed, 0.0, "Velocidade vertical deve aumentar")
	assert_ne(controller.lateral_speed, 0.0, "Velocidade lateral deve aumentar")

func test_reset() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 30.0
	controller.reset()
	assert_eq(controller.speed, 0.0, "Velocidade deve ser resetada para zero")
	assert_eq(controller.lateral_speed, 0.0, "Velocidade lateral deve ser resetada para zero")

func test_vertical_position_at_zero_speed() -> void:
	controller.speed = 0.0
	var pos = controller.get_vertical_position()
	assert_eq(pos, GameConfig.vertical_position_max, "Posição deve ser vertical_position_max quando velocidade é zero")

func test_vertical_position_at_max_speed() -> void:
	controller.speed = GameConfig.max_speed
	var pos = controller.get_vertical_position()
	assert_eq(pos, GameConfig.vertical_position_min, "Posição deve ser vertical_position_min quando velocidade é máxima")

func test_vertical_interpolation() -> void:
	controller.speed = GameConfig.max_speed / 2.0
	var pos = controller.get_vertical_position()
	assert_gt(pos, GameConfig.vertical_position_min, "Posição deve ser maior que mínimo")
	assert_lt(pos, GameConfig.vertical_position_max, "Posição deve ser menor que máximo")

func test_vertical_bounds() -> void:
	controller.speed = 0.0
	var pos_min = controller.get_vertical_position()
	controller.speed = GameConfig.max_speed
	var pos_max = controller.get_vertical_position()
	assert_le(pos_min, pos_max, "Posição máxima deve ser menor ou igual à mínima")

func test_diagonal_accelerate_left() -> void:
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_gt(controller.speed, 0.0, "Velocidade vertical deve aumentar")
	assert_lt(controller.lateral_speed, 0.0, "Velocidade lateral deve ser negativa (esquerda)")

func test_diagonal_accelerate_right() -> void:
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_gt(controller.speed, 0.0, "Velocidade vertical deve aumentar")
	assert_gt(controller.lateral_speed, 0.0, "Velocidade lateral deve ser positiva (direita)")

func test_diagonal_brake_left() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_lt(controller.speed, 50.0, "Velocidade vertical deve diminuir")
	assert_lt(controller.lateral_speed, 0.0, "Velocidade lateral deve ser negativa (esquerda)")

func test_diagonal_brake_right() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_lt(controller.speed, 50.0, "Velocidade vertical deve diminuir")
	assert_gt(controller.lateral_speed, 0.0, "Velocidade lateral deve ser positiva (direita)")

func test_lateral_cancellation() -> void:
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_eq(controller.lateral_speed, 0.0, "Movimentos laterais opostos devem se cancelar")

func test_sprite_swap_physics_unchanged() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 30.0
	var initial_speed = controller.speed
	var initial_lateral = controller.lateral_speed
	controller._process(0.1)
	assert_ne(controller.speed, initial_speed, "Velocidade deve mudar")
	assert_ne(controller.lateral_speed, initial_lateral, "Velocidade lateral deve mudar")

func test_default_sprite_loaded() -> void:
	var vehicle = PlayerVehicle.new()
	assert_not_null(vehicle.sprite, "Sprite deve ser carregado")

func test_fallback_placeholder() -> void:
	var vehicle = PlayerVehicle.new()
	vehicle._load_sprite("res://nonexistent.png")
	assert_not_null(vehicle.sprite.texture, "Placeholder deve ser criado")
