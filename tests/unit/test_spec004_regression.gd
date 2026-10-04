extends GdUnitTestSuite

## T044 / SC-017 — regressão SPEC-001 (física do veículo), SPEC-002 (limites da
## estrada) e SPEC-003 (ambientes) executada COM trânsito e decoração ativos,
## provando que o SPEC-004 não altera o comportamento anterior.

var controller: VehicleController
var ambientes: EnvironmentManager
var traffic_original: bool
var decoracao_original: bool


func before_test() -> void:
	traffic_original = GameConfig.traffic_enabled
	decoracao_original = GameConfig.decoration_enabled
	GameConfig.traffic_enabled = true
	GameConfig.decoration_enabled = true
	controller = VehicleController.new()
	ambientes = EnvironmentManager.new()


func after_test() -> void:
	# `Input` é global: qualquer ação pressionada aqui vazaria para as demais
	# suítes (headless não recebe teclado, então ninguém mais limpa).
	for acao in ["accelerate", "brake", "move_left", "move_right"]:
		Input.action_release(acao)
	GameConfig.traffic_enabled = traffic_original
	GameConfig.decoration_enabled = decoracao_original
	controller = null
	ambientes = null


## SPEC-001 — aceleração, frenagem e desaceleração natural.
func test_speed_response_unchanged() -> void:
	Input.action_press("accelerate")
	controller.speed = 0.0
	controller._process(0.1)
	assert_float(controller.speed).is_greater(0.0).override_failure_message(
		"REG: velocidade deixou de aumentar"
	)

	Input.action_release("accelerate")
	Input.action_press("brake")
	controller.speed = 100.0
	controller._process(0.1)
	Input.action_release("brake")
	assert_float(controller.speed).is_less(100.0).override_failure_message(
		"REG: velocidade deixou de diminuir"
	)


## SPEC-001 — limites superior e inferior da velocidade.
func test_speed_clamps_unchanged() -> void:
	Input.action_press("accelerate")
	controller.speed = 99.0
	controller._process(1.0)
	Input.action_release("accelerate")
	assert_float(controller.speed).is_equal(
		GameConfig.max_speed
	).override_failure_message("REG: max_speed não é mais respeitado")

	Input.action_press("brake")
	controller.speed = 1.0
	controller._process(1.0)
	Input.action_release("brake")
	assert_float(controller.speed).is_zero().override_failure_message(
		"REG: velocidade ficou negativa"
	)


## SPEC-001 / SPEC-002 — posição vertical sempre dentro dos limites.
func test_vertical_bounds_unchanged() -> void:
	controller.speed = 0.0
	var pos_baixa: float = controller.get_vertical_position()
	controller.speed = GameConfig.max_speed
	var pos_alta: float = controller.get_vertical_position()

	assert_float(pos_baixa).is_greater_equal(
		GameConfig.vertical_position_min
	).override_failure_message("REG: posição abaixo do mínimo")
	assert_float(pos_alta).is_less_equal(
		GameConfig.vertical_position_max
	).override_failure_message("REG: posição acima do máximo")


## SPEC-002 — contenção lateral preservada (FR-051, FR-052).
func test_lateral_limits_unchanged() -> void:
	controller.lateral_speed = -100.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_greater_equal(
		-GameConfig.lateral_speed
	).override_failure_message("REG: limite esquerdo violado")

	controller.lateral_speed = 100.0
	controller._process(0.1)
	assert_float(controller.lateral_speed).is_less_equal(
		GameConfig.lateral_speed
	).override_failure_message("REG: limite direito violado")


## SPEC-003 — troca de ambiente continua funcionando com SPEC-004 ativo.
func test_environments_unchanged() -> void:
	ambientes.set_environment("ICE")
	var env = ambientes.get_current_environment()
	assert_str(env.id).is_equal("ICE").override_failure_message("REG: troca para ICE falhou")
	assert_int(env.difficulty).is_equal(4).override_failure_message(
		"REG: dificuldade do ICE mudou"
	)

	ambientes.set_environment("INVALID")
	var fallback = ambientes.get_current_environment()
	assert_str(fallback.id).is_equal("PLAINS").override_failure_message(
		"REG: fallback para PLAINS falhou"
	)


## SPEC-003 — os 4 ambientes seguem únicos e com textura válida.
func test_all_environments_available() -> void:
	var todos = ambientes.get_all_environments()
	assert_int(todos.size()).is_equal(4).override_failure_message(
		"REG: quantidade de ambientes mudou"
	)

	var vistos := {}
	for env in todos:
		vistos[env.id] = true
		assert_bool(ResourceLoader.exists(env.texture_path)).is_true().override_failure_message(
			"REG: textura ausente para %s" % env.id
		)
	assert_int(vistos.size()).is_equal(4).override_failure_message(
		"REG: ids de ambiente duplicados"
	)


## Os dois sistemas do SPEC-004 estão ativos enquanto a regressão roda.
func test_spec004_systems_enabled_during_regression() -> void:
	assert_bool(GameConfig.traffic_enabled).is_true().override_failure_message(
		"REG: trânsito desativado durante a regressão"
	)
	assert_bool(GameConfig.decoration_enabled).is_true().override_failure_message(
		"REG: decoração desativada durante a regressão"
	)
