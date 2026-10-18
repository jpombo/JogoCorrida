extends GdUnitTestSuite

## SPEC-009 / T005 (US1 — consumo) + T021 (US3 — penalidade).
## Combustível coerente com o modo (R3, SC-008): consumo POR KM constante
## entre Relaxante/Normal/Desafio (mesma distância ⇒ mesmo consumo), sem
## aplicação dupla do fator, regressão 1× idêntica ao modelo atual e
## penalidade de colisão = ambiente × modo (SC-007).

var sistema: FuelSystem
var _ambiente_original: String
var _inicial_original: float


func before_test() -> void:
	_ambiente_original = GameConfig.current_environment_id
	_inicial_original = GameConfig.fuel_initial_amount
	GameConfig.fuel_initial_amount = -1.0
	sistema = FuelSystem.new()
	sistema.reset()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.fuel_initial_amount = _inicial_original
	sistema.free()


## Consome em passos sintéticos e devolve a variação total.
func _drenar(velocidade: float, passos: int, delta: float) -> float:
	var antes: float = sistema.get_atual()
	for i in passos:
		sistema.update(delta, velocidade)
	return antes - sistema.get_atual()


## SC-008 — mesma distância dirigida (1 km) consome o MESMO combustível nos
## 3 modos: taxa/s escala com o fator igual à velocidade (consumo por km
## constante — a capacidade derivada da SPEC-008 continua válida, R3).
func test_01_consumo_por_km_constante_entre_modos() -> void:
	var km: float = 1.0
	var consumos: Dictionary = {}
	for modo in ["relaxing", "normal", "challenge"]:
		var dm := DifficultyManager.new()
		dm.definir_modo(modo)
		var fator: float = dm.multiplicador_velocidade()
		sistema.fator_velocidade = fator

		var velocidade: float = GameConfig.max_speed * fator * 0.75
		var delta: float = 1.0 / 60.0
		var passos: int = int(km / (velocidade * GameConfig.track_units_to_km * delta))
		consumos[modo] = _drenar(velocidade, passos, delta)
		sistema.reset()

	assert_float(consumos["normal"]).is_equal_approx(consumos["relaxing"], consumos["relaxing"] * 0.01)
	assert_float(consumos["challenge"]).is_equal_approx(consumos["relaxing"], consumos["relaxing"] * 0.01)
	assert_float(consumos["relaxing"]).is_greater(0.0)
	sistema.fator_velocidade = 1.0


## Sem aplicação dupla: re-injetar o mesmo fator não dobra a taxa — a taxa
## final é exatamente modelo × fator (R3, contrato §3: aplicação única).
func test_02_sem_aplicacao_dupla() -> void:
	sistema.fator_velocidade = 2.0
	sistema.fator_velocidade = 2.0  # refresh de corrida repetido (idempotente)
	# normalizada = 150 / (100 × 2) = 0,75 → modelo 0,6 + 0,75×1,4 = 1,65 × 2 = 3,3/s
	var taxa_esperada: float = (0.6 + 0.75 * GameConfig.fuel_consumption_speed_factor) * 2.0
	var drenado: float = _drenar(150.0, 5, 1.0)
	assert_float(drenado).is_equal_approx(5.0 * taxa_esperada, 0.001)
	sistema.fator_velocidade = 1.0


## Regressão 1× — sem injeção (default 1,0) o modelo é exatamente o atual:
## normalização pelo teto base e clamp [min, max] do SPEC-007.
func test_03_regressao_1x_identica() -> void:
	var taxa_esperada: float = clampf(
		GameConfig.fuel_consumption_min
			+ 1.0 * GameConfig.fuel_consumption_speed_factor,
		GameConfig.fuel_consumption_min,
		GameConfig.fuel_consumption_max
	)
	var drenado: float = _drenar(100.0, 5, 1.0)
	assert_float(drenado).is_equal_approx(5.0 * taxa_esperada, 0.001)


## Teto efetivo: a máxima do modo atinge exatamente a taxa máxima escalada
## (normalização pelo teto efetivo — nunca satura indevidamente).
func test_04_taxa_maxima_escalada() -> void:
	sistema.fator_velocidade = 3.0
	var drenado: float = _drenar(300.0, 3, 1.0)
	var max_esperado: float = GameConfig.fuel_consumption_max * 3.0
	assert_float(drenado).is_equal_approx(3.0 * max_esperado, 0.001)
	sistema.fator_velocidade = 1.0


## Repouso (velocidade zero) usa o consumo em repouso — não escala por
## velocidade (FR-009 intacto).
func test_05_repouso_inalterado() -> void:
	sistema.fator_velocidade = 3.0
	GameConfig.fuel_consumption_idle = 1.5
	var drenado: float = _drenar(0.0, 2, 1.0)
	assert_float(drenado).is_equal(3.0)
	GameConfig.fuel_consumption_idle = 0.0
	sistema.fator_velocidade = 1.0


# ---------------------------------------------------------------------------
# T021 (US3) — penalidade de colisão = ambiente × modo (SC-007)
# ---------------------------------------------------------------------------

## Penalidade efetiva = collision_fuel_penalty[ambiente] × fator do modo:
## Desafio 1,5× e Relaxante 0,5× sobre a base do ambiente.
func test_06_penalidade_ambiente_por_modo() -> void:
	GameConfig.current_environment_id = "FOREST"
	var base: float = 3.0

	sistema.fator_penalidade_colisao = 1.5
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal_approx(antes - base * 1.5, 0.001)

	sistema.reset()
	sistema.fator_penalidade_colisao = 0.5
	antes = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal_approx(antes - base * 0.5, 0.001)
	sistema.fator_penalidade_colisao = 1.0


## Aplicação única por evento: 1 chamada = 1 desconto = 1 emissão.
func test_07_penalidade_aplicacao_unica() -> void:
	GameConfig.current_environment_id = "ICE"
	sistema.fator_penalidade_colisao = 1.5
	var mudancas := [0]
	sistema.fuel_changed.connect(func(_a, _c): mudancas[0] += 1)
	var antes: float = sistema.get_atual()
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal_approx(antes - 3.0 * 1.5, 0.001)
	assert_int(mudancas[0]).is_equal(1)
	sistema.fator_penalidade_colisao = 1.0


## Penalidade base 0 × fator = 0: PLAINS/DESERT continuam sem risco em
## qualquer modo (0 × 1,5 = 0 — nunca negativa).
func test_08_penalidade_base_zero_por_modo() -> void:
	sistema.fator_penalidade_colisao = 1.5
	for ambiente in ["PLAINS", "DESERT"]:
		GameConfig.current_environment_id = ambiente
		var antes: float = sistema.get_atual()
		sistema.on_player_collision()
		assert_float(sistema.get_atual()).is_equal(antes)
	sistema.fator_penalidade_colisao = 1.0
