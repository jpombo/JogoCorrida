extends GdUnitTestSuite

## SPEC-008 / teste obrigatório D (dimensionamento) — US5 + parte de F.
## Capacidade derivada em tempo de execução: fórmula, regressão sem override,
## guarda de distância zero e corrida de referência com sobra de 15%–35%
## (SC-006, SC-008, SC-016, research R3).

var sistema: FuelSystem
var track: TrackManager

var _total_original: float
var _por_km_original: float
var _margem_original: float
var _capacidade_original: float
var _inicial_original: float
var _min_original: float
var _max_original: float
var _fator_original: float


func before_test() -> void:
	_total_original = GameConfig.track_total_distance
	_por_km_original = GameConfig.fuel_consumption_per_distance
	_margem_original = GameConfig.fuel_safety_margin
	_capacidade_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_min_original = GameConfig.fuel_consumption_min
	_max_original = GameConfig.fuel_consumption_max
	_fator_original = GameConfig.fuel_consumption_speed_factor

	GameConfig.track_total_distance = 5.0
	GameConfig.fuel_consumption_per_distance = 60.0
	GameConfig.fuel_safety_margin = 60.0
	GameConfig.fuel_initial_amount = -1.0

	sistema = FuelSystem.new()
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()


func after_test() -> void:
	GameConfig.track_total_distance = _total_original
	GameConfig.fuel_consumption_per_distance = _por_km_original
	GameConfig.fuel_safety_margin = _margem_original
	GameConfig.fuel_capacity = _capacidade_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_consumption_min = _min_original
	GameConfig.fuel_consumption_max = _max_original
	GameConfig.fuel_consumption_speed_factor = _fator_original
	sistema.free()
	track.free()


## D1 — fórmula: capacidade = track_total_distance × per_distance + margin.
func test_d1_formula_de_dimensionamento() -> void:
	var esperado: float = 5.0 * 60.0 + 60.0  # 360.0
	sistema.definir_capacidade_derivada(esperado)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(esperado)
	assert_float(sistema.get_atual()).is_equal(esperado)


## D2 — alterar a distância da corrida muda o tanque automaticamente
## (SC-016: uma única fonte de verdade).
func test_d2_distancia_muda_tanque() -> void:
	sistema.definir_capacidade_derivada(10.0 * 60.0 + 60.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(660.0)

	sistema.definir_capacidade_derivada(2.0 * 60.0 + 60.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(180.0)


## D3 — regressão SPEC-007: sem override, o reset usa GameConfig.fuel_capacity
## e a suíte antiga continua verde (SC-013/SC-014).
func test_d3_regressao_sem_override() -> void:
	GameConfig.fuel_capacity = 100.0
	sistema.definir_capacidade_derivada(-1.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(100.0)
	assert_float(sistema.get_atual()).is_equal(100.0)


## D4 — corrida de referência sintética: velocidade constante máxima, sem
## colisões nem coletas, cruza o total com sobra de combustível entre 15% e
## 35% da capacidade (SC-006, FR-039).
func test_d4_corrida_referencia_sobra() -> void:
	var delta: float = 1.0 / 60.0
	var velocidade: float = GameConfig.max_speed  # 100.0

	sistema.definir_capacidade_derivada(
		GameConfig.track_total_distance * GameConfig.fuel_consumption_per_distance
		+ GameConfig.fuel_safety_margin
	)
	sistema.reset()
	track.setup(GameConfig.track_total_distance)
	track.reset()

	var passos: int = 0
	while track.get_restante() > 0.0 and sistema.get_atual() > 0.0 and passos < 20000:
		track.update(delta, velocidade)
		sistema.update(delta, velocidade)
		passos += 1

	# A corrida completa: distância limitada ao total (SC-004).
	assert_bool(track.get_restante() <= 0.0).is_true()
	assert_float(track.get_percorrida()).is_equal_approx(GameConfig.track_total_distance, 0.0001)

	# Sobra dentro da faixa de calibração (SC-006).
	var sobra: float = sistema.get_atual() / sistema.get_capacidade()
	assert_float(sobra).is_between(0.15, 0.35)


## D5 — guarda de configuração: distância zero não quebra (margin vira a
## capacidade; nenhuma divisão por zero).
func test_d5_guarda_distancia_zero() -> void:
	sistema.definir_capacidade_derivada(0.0 * 60.0 + 60.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(60.0)
	assert_float(sistema.get_atual()).is_equal(60.0)


## D6 — definir(-1) limpa o override e volta ao valor nominal.
func test_d6_limpar_override() -> void:
	GameConfig.fuel_capacity = 80.0
	sistema.definir_capacidade_derivada(500.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(500.0)
	sistema.definir_capacidade_derivada(-1.0)
	sistema.reset()
	assert_float(sistema.get_capacidade()).is_equal(80.0)
