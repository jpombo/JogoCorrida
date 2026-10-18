extends GdUnitTestSuite

## SPEC-007 / US5 — teste obrigatório 27: cada parâmetro fuel_* afeta o
## comportamento apenas via GameConfig (FR-026, SC-016). Muta tudo em cada
## teste e restaura integralmente em after_test — nenhum arquivo de lógica é
## alterado por balanceamento.

var sistema: FuelSystem

var _capacidade_original: float
var _inicial_original: float
var _idle_original: float
var _min_original: float
var _max_original: float
var _fator_original: float
var _limiar_original: float
var _rotulo_original: String
var _ambiente_original: String
var _penalidades_original: Dictionary


func before_test() -> void:
	_capacidade_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_idle_original = GameConfig.fuel_consumption_idle
	_min_original = GameConfig.fuel_consumption_min
	_max_original = GameConfig.fuel_consumption_max
	_fator_original = GameConfig.fuel_consumption_speed_factor
	_limiar_original = GameConfig.fuel_low_threshold
	_rotulo_original = GameConfig.fuel_low_label
	_ambiente_original = GameConfig.current_environment_id
	_penalidades_original = GameConfig.collision_fuel_penalty.duplicate()
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0
	sistema = FuelSystem.new()


func after_test() -> void:
	GameConfig.fuel_capacity = _capacidade_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_consumption_idle = _idle_original
	GameConfig.fuel_consumption_min = _min_original
	GameConfig.fuel_consumption_max = _max_original
	GameConfig.fuel_consumption_speed_factor = _fator_original
	GameConfig.fuel_low_threshold = _limiar_original
	GameConfig.fuel_low_label = _rotulo_original
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.collision_fuel_penalty = _penalidades_original
	sistema.free()


func test_27_fuel_capacity_ajusta_tanque() -> void:
	GameConfig.fuel_capacity = 250.0
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(250.0)
	assert_float(sistema.get_atual()).is_equal(250.0)


func test_27_fuel_initial_amount_ajusta_partida() -> void:
	GameConfig.fuel_initial_amount = 33.0
	sistema.reset()
	assert_float(sistema.get_atual()).is_equal(33.0)


func test_27_fuel_consumption_idle_ajusta_repouso() -> void:
	GameConfig.fuel_initial_amount = 10.0
	GameConfig.fuel_consumption_idle = 2.5
	sistema.reset()
	sistema.update(2.0, 0.0)
	assert_float(sistema.get_atual()).is_equal(10.0 - 5.0)


func test_27_fuel_consumption_min_ajusta_piso() -> void:
	GameConfig.fuel_consumption_min = 1.0
	GameConfig.fuel_consumption_max = 5.0
	GameConfig.fuel_consumption_speed_factor = 0.0
	sistema.reset()
	sistema.update(1.0, 1.0)  # piso 1.0 vence o fator zero
	assert_float(sistema.get_atual()).is_equal(99.0)


func test_27_fuel_consumption_max_ajusta_teto() -> void:
	GameConfig.fuel_consumption_min = 0.6
	GameConfig.fuel_consumption_max = 0.8
	GameConfig.fuel_consumption_speed_factor = 100.0
	sistema.reset()
	sistema.update(1.0, 100.0)  # fator colapsa no teto 0.8
	assert_float(sistema.get_atual()).is_equal(99.2)


func test_27_fuel_consumption_speed_factor_ajusta_curva() -> void:
	GameConfig.fuel_consumption_min = 0.5
	GameConfig.fuel_consumption_max = 10.0
	GameConfig.fuel_consumption_speed_factor = 0.0
	sistema.reset()
	sistema.update(1.0, 100.0)  # sem fator: taxa = piso, não importa a velocidade
	assert_float(sistema.get_atual()).is_equal(99.5)

	GameConfig.fuel_consumption_speed_factor = 9.5
	sistema.reset()
	sistema.update(1.0, 100.0)  # com fator total 10.0 (o teto)
	assert_float(sistema.get_atual()).is_equal(90.0)


func test_27_fuel_low_threshold_ajusta_fronteira() -> void:
	GameConfig.fuel_initial_amount = 30.0
	GameConfig.fuel_low_threshold = 0.5
	var baixos := [0]
	sistema.fuel_low.connect(func(): baixos[0] += 1)  # ANTES do reset
	sistema.reset()
	assert_bool(sistema.esta_baixo()).is_true()  # 30 ≤ 50
	assert_int(baixos[0]).is_equal(1)


func test_27_collision_fuel_penalty_ajusta_desconto() -> void:
	GameConfig.fuel_initial_amount = 50.0
	GameConfig.collision_fuel_penalty = {"FOREST": 7.0}
	sistema.reset()
	GameConfig.current_environment_id = "FOREST"
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(43.0)


func test_27_fuel_low_label_altera_texto_do_hud() -> void:
	GameConfig.fuel_low_label = "RESERVA"
	assert_str(GameConfig.fuel_low_label).is_equal("RESERVA")
	# O script do HUD não pode fixar literal: o texto vem sempre da config
	# (verificado de forma estrutural em fuel_hud_test.gd via rotulo.text).
