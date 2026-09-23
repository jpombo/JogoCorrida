extends GdUnitTestSuite

var controller: VehicleController

func before_each() -> void:
	controller = VehicleController.new()

func after_each() -> void:
	controller = null

func test_boundary_collision_left() -> void:
	controller.lateral_speed = -100.0
	controller._process(0.1)
	assert_ge(controller.lateral_speed, -GameConfig.lateral_speed, "Velocidade lateral deve ser limitada")

func test_boundary_collision_right() -> void:
	controller.lateral_speed = 100.0
	controller._process(0.1)
	assert_le(controller.lateral_speed, GameConfig.lateral_speed, "Velocidade lateral deve ser limitada")

func test_vertical_bounds() -> void:
	controller.speed = GameConfig.max_speed
	var pos = controller.get_vertical_position()
	assert_ge(pos, GameConfig.vertical_position_min, "Posição não deve ser menor que mínimo")
	assert_le(pos, GameConfig.vertical_position_max, "Posição não deve ser maior que máximo")

func test_no_teleportation() -> void:
	controller.lateral_speed = 0.0
	controller._process(0.1)
	assert_eq(controller.lateral_speed, 0.0, "Não deve haver teleportação")
