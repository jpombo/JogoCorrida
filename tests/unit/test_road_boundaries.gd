extends GdUnitTestSuite

var controller: VehicleController

func before_test() -> void:
	controller = VehicleController.new()

func after_test() -> void:
	controller = null

func test_boundary_collision_left() -> void:
	controller.lateral_speed = -100.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_greater_equal(-GameConfig.lateral_speed).override_failure_message("Velocidade lateral deve ser limitada")

func test_boundary_collision_right() -> void:
	controller.lateral_speed = 100.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_less_equal(GameConfig.lateral_speed).override_failure_message("Velocidade lateral deve ser limitada")

func test_vertical_bounds() -> void:
	controller.speed = GameConfig.max_speed
	var pos = controller.get_vertical_position()
	assert_float(pos).is_greater_equal(GameConfig.vertical_position_min).override_failure_message("Posição não deve ser menor que mínimo")
	assert_float(pos).is_less_equal(GameConfig.vertical_position_max).override_failure_message("Posição não deve ser maior que máximo")

func test_no_teleportation() -> void:
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_zero().override_failure_message("Não deve haver teleportação")