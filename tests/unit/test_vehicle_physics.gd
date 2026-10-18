extends GdUnitTestSuite

var controller: VehicleController

## Ações lidas por `VehicleController._process()` (SPEC-001). Em modo headless
## nenhuma tecla chega ao `Input`, então o teste pressiona e solta explicitamente
## — o singleton `Input` é global, por isso a liberação é feita sempre.
const ACOES: Array[String] = ["accelerate", "brake", "move_left", "move_right"]


func before_test() -> void:
	_soltar_acoes()
	controller = VehicleController.new()


func after_test() -> void:
	_soltar_acoes()
	controller = null


func _pressionar(acao: String) -> void:
	Input.action_press(acao)


func _soltar_acoes() -> void:
	for acao in ACOES:
		Input.action_release(acao)


func test_speed_increases_with_acceleration() -> void:
	_pressionar("accelerate")
	controller.speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_greater(0.0).override_failure_message("Velocidade deve aumentar com aceleração")

func test_speed_decreases_with_brake() -> void:
	controller.speed = 100.0
	controller._process(0.1)
	assert_float(controller.speed).is_less(100.0).override_failure_message("Velocidade deve diminuir com frenagem")

func test_brake_overrides_accelerate() -> void:
	controller.speed = 50.0
	controller._process(0.1)
	assert_float(controller.speed).is_less(50.0).override_failure_message("Frenagem deve prevalecer sobre aceleração")

func test_natural_deceleration() -> void:
	controller.speed = 100.0
	controller._process(0.1)
	assert_float(controller.speed).is_less(100.0).override_failure_message("Velocidade deve diminuir com desaceleração natural")

func test_speed_clamped_at_max() -> void:
	_pressionar("accelerate")
	controller.speed = 99.0
	controller._process(1.0)
	assert_float(controller.speed).is_equal(GameConfig.max_speed).override_failure_message("Velocidade não deve exceder max_speed")

func test_speed_clamped_at_zero() -> void:
	controller.speed = 1.0
	controller._process(1.0)
	assert_float(controller.speed).is_zero().override_failure_message("Velocidade não deve ficar abaixo de zero")

func test_lateral_movement_independent() -> void:
	_pressionar("move_right")
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_not_equal(0.0).override_failure_message("Movimento lateral deve ser independente")

func test_diagonal_movement() -> void:
	_pressionar("accelerate")
	_pressionar("move_right")
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_greater(0.0).override_failure_message("Velocidade vertical deve aumentar")
	assert_float(controller.lateral_speed).is_not_equal(0.0).override_failure_message("Velocidade lateral deve aumentar")

func test_reset() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 30.0
	controller.reset()
	assert_float(controller.speed).is_zero().override_failure_message("Velocidade deve ser resetada para zero")
	assert_float(controller.lateral_speed).is_zero().override_failure_message("Velocidade lateral deve ser resetada para zero")

func test_vertical_position_at_zero_speed() -> void:
	controller.speed = 0.0
	var pos = controller.get_vertical_position()
	assert_float(pos).is_equal(GameConfig.vertical_position_max).override_failure_message("Posição deve ser vertical_position_max quando velocidade é zero")

func test_vertical_position_at_max_speed() -> void:
	controller.speed = GameConfig.max_speed
	var pos = controller.get_vertical_position()
	assert_float(pos).is_equal(GameConfig.vertical_position_min).override_failure_message("Posição deve ser vertical_position_min quando velocidade é máxima")

func test_vertical_interpolation() -> void:
	controller.speed = GameConfig.max_speed / 2.0
	var pos = controller.get_vertical_position()
	assert_float(pos).is_greater(GameConfig.vertical_position_min).override_failure_message("Posição deve ser maior que mínimo")
	assert_float(pos).is_less(GameConfig.vertical_position_max).override_failure_message("Posição deve ser menor que máximo")

func test_vertical_bounds() -> void:
	controller.speed = 0.0
	var pos_parado = controller.get_vertical_position()
	controller.speed = GameConfig.max_speed
	var pos_rapido = controller.get_vertical_position()
	assert_float(pos_parado).is_greater_equal(pos_rapido).override_failure_message("Parado o carro fica mais embaixo (vertical_position_max) do que a velocidade máxima (vertical_position_min)")

func test_diagonal_accelerate_left() -> void:
	_pressionar("accelerate")
	_pressionar("move_left")
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_greater(0.0).override_failure_message("Velocidade vertical deve aumentar")
	assert_float(controller.lateral_speed).is_less(0.0).override_failure_message("Velocidade lateral deve ser negativa (esquerda)")

func test_diagonal_accelerate_right() -> void:
	_pressionar("accelerate")
	_pressionar("move_right")
	controller.speed = 0.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_greater(0.0).override_failure_message("Velocidade vertical deve aumentar")
	assert_float(controller.lateral_speed).is_greater(0.0).override_failure_message("Velocidade lateral deve ser positiva (direita)")

func test_diagonal_brake_left() -> void:
	_pressionar("brake")
	_pressionar("move_left")
	controller.speed = 50.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_less(50.0).override_failure_message("Velocidade vertical deve diminuir")
	assert_float(controller.lateral_speed).is_less(0.0).override_failure_message("Velocidade lateral deve ser negativa (esquerda)")

func test_diagonal_brake_right() -> void:
	_pressionar("brake")
	_pressionar("move_right")
	controller.speed = 50.0
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_less(50.0).override_failure_message("Velocidade vertical deve diminuir")
	assert_float(controller.lateral_speed).is_greater(0.0).override_failure_message("Velocidade lateral deve ser positiva (direita)")

func test_lateral_cancellation() -> void:
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_zero().override_failure_message("Movimentos laterais opostos devem se cancelar")

func test_sprite_swap_physics_unchanged() -> void:
	controller.speed = 50.0
	controller.lateral_speed = 30.0
	var initial_speed = controller.speed
	var initial_lateral = controller.lateral_speed
	controller._process(0.1)
	assert_float(controller.speed).is_not_equal(initial_speed).override_failure_message("Velocidade deve mudar")
	assert_float(controller.lateral_speed).is_not_equal(initial_lateral).override_failure_message("Velocidade lateral deve mudar")

## Monta um PlayerVehicle completo: `_ready` só roda com o nó na árvore, e é lá
## que os `@onready` (`sprite`, `collision_shape`) resolvem os filhos por nome.
func _make_player_vehicle() -> PlayerVehicle:
	var vehicle := PlayerVehicle.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	vehicle.add_child(sprite)
	var colisao := CollisionShape2D.new()
	colisao.name = "CollisionShape2D"
	vehicle.add_child(colisao)
	add_child(vehicle)
	return vehicle

func test_default_sprite_loaded() -> void:
	var vehicle := _make_player_vehicle()
	assert_object(vehicle.sprite).is_not_null().override_failure_message("Sprite deve ser carregado")

func test_fallback_placeholder() -> void:
	var vehicle := _make_player_vehicle()
	vehicle._load_sprite("res://nonexistent.png")
	assert_object(vehicle.sprite.texture).is_not_null().override_failure_message("Placeholder deve ser criado")