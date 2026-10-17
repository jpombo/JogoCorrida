extends GdUnitTestSuite

## SPEC-011 / T007 (US1) — Fórmula de pontuação (data-model §2,
## SC-002/SC-003, FR-004…FR-007): distância × peso + troféus × peso −
## perda × peso, clamp ≥ 0; consumo normal gera 0 de penalidade e a perda
## de colisão é contada 1× pelo acumulador do FuelSystem (research R4).

var _peso_distancia_original: float
var _peso_trofeu_original: float
var _peso_penalidade_original: float
var _cap_original: float
var _inicial_original: float
var _ambiente_original: String


func before_test() -> void:
	_peso_distancia_original = GameConfig.score_peso_distancia
	_peso_trofeu_original = GameConfig.score_peso_trofeu
	_peso_penalidade_original = GameConfig.score_peso_penalidade
	_cap_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_ambiente_original = String(GameConfig.current_environment_id)
	GameConfig.score_peso_distancia = 100.0
	GameConfig.score_peso_trofeu = 500.0
	GameConfig.score_peso_penalidade = 10.0
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = 100.0
	# PLAINS/DESERT têm penalidade 0,0 por design — FOREST tem penalidade
	# positiva para exercitar o acumulador (edge case da SPEC-008).
	GameConfig.current_environment_id = "FOREST"


func after_test() -> void:
	GameConfig.score_peso_distancia = _peso_distancia_original
	GameConfig.score_peso_trofeu = _peso_trofeu_original
	GameConfig.score_peso_penalidade = _peso_penalidade_original
	GameConfig.fuel_capacity = _cap_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.current_environment_id = _ambiente_original


## Fórmula completa com os 3 termos (2,5 km × 100 + 3 troféus × 500 −
## 12,0 de perda × 10 = 250 + 1500 − 120 = 1630).
func test_01_formula_completa() -> void:
	var pm := ProgressManager.new()
	var p: float = pm.calcular_pontuacao(2.5, 3, 12.0)
	assert_float(p).is_equal_approx(250.0 + 1500.0 - 120.0, 0.001)


## Termos negativos/zerados nunca reduzem abaixo do esperado: perda zero
## (consumo normal) gera exatamente a soma dos 2 primeiros termos.
func test_02_sem_perda_sem_penalidade() -> void:
	var pm := ProgressManager.new()
	var p: float = pm.calcular_pontuacao(1.0, 1, 0.0)
	assert_float(p).is_equal_approx(100.0 + 500.0, 0.001)


## Clamp ≥ 0 (FR-007): perda maior que a recompensa zera a pontuação.
func test_03_clamp_positivo() -> void:
	var pm := ProgressManager.new()
	assert_float(pm.calcular_pontuacao(1.0, 0, 9999.0)).is_equal(0.0)


## Clamp também ignora entradas negativas (defesa de domínio).
func test_04_entradas_negativas_ignoradas() -> void:
	var pm := ProgressManager.new()
	assert_float(pm.calcular_pontuacao(-5.0, -2, -3.0)).is_equal(0.0)


## T012 — consumo normal nunca toca no acumulador de perda (research R4).
func test_05_consumo_normal_sem_perda() -> void:
	var fs := FuelSystem.new()
	fs.definir_capacidade_derivada(100.0)
	fs.reset()
	for i in 10:
		fs.update(1.0, 100.0)
	assert_float(fs.get_perda_colisao_corrida()).is_equal(0.0)
	fs.free()


## T012/FR-007 — colisão conta o delta REAL uma única vez (já com o fator
## de penalidade do modo, clamp incluso no FuelSystem).
func test_06_colisao_conta_delta_real_uma_vez() -> void:
	var fs := FuelSystem.new()
	fs.definir_capacidade_derivada(100.0)
	fs.reset()
	var antes: float = fs.get_atual()

	fs.on_player_collision()

	var esperado: float = antes - fs.get_atual()
	assert_bool(esperado > 0.0).is_true().override_failure_message(
		"collision_fuel_penalty do ambiente não descontou nada (esperado > 0)"
	)
	assert_float(fs.get_perda_colisao_corrida()).is_equal_approx(esperado, 0.0001)
	fs.free()


## T012 — `reset()` zera o acumulador junto com o resto do estado.
func test_07_reset_zera_acumulador() -> void:
	var fs := FuelSystem.new()
	fs.definir_capacidade_derivada(100.0)
	fs.reset()
	fs.on_player_collision()
	assert_bool(fs.get_perda_colisao_corrida() > 0.0).is_true()
	fs.reset()
	assert_float(fs.get_perda_colisao_corrida()).is_equal(0.0)
	fs.free()


## SC-003 — pontuação de uma corrida real usa o acumulador do próprio
## FuelSystem: vitória com 1 colisão perde exatamente perda × peso.
func test_07b_pontuacao_usa_acumulador_real() -> void:
	var fs := FuelSystem.new()
	fs.definir_capacidade_derivada(100.0)
	fs.reset()
	fs.on_player_collision()
	var perda: float = fs.get_perda_colisao_corrida()
	fs.free()

	var pm := ProgressManager.new()
	var p: float = pm.calcular_pontuacao(1.0, 0, perda)
	assert_float(p).is_equal_approx(
		maxf(100.0 - perda * GameConfig.score_peso_penalidade, 0.0), 0.001
	)
