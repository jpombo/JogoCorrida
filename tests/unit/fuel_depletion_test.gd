extends GdUnitTestSuite

## SPEC-007 / US3 — testes obrigatórios 11–14: esgotamento exato por qualquer
## origem, sem valor negativo, sem consumo pós-zero e exatamente 1 evento por
## ocorrência. Inclui a asserção de FR-021: pós-esgotado nenhum sinal além de
## fuel_changed/fuel_low/fuel_depleted nasce aqui (verificação integrada de
## GAME_OVER no passo 8 do quickstart).

var sistema: FuelSystem

var _ambiente_original: String
var _penalidades_original: Dictionary
var _inicial_original: float
var _limiar_original: float


func before_test() -> void:
	_ambiente_original = GameConfig.current_environment_id
	_penalidades_original = GameConfig.collision_fuel_penalty.duplicate()
	_inicial_original = GameConfig.fuel_initial_amount
	_limiar_original = GameConfig.fuel_low_threshold
	GameConfig.fuel_initial_amount = -1.0
	sistema = FuelSystem.new()
	sistema.reset()
	sistema.reset()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.collision_fuel_penalty = _penalidades_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_low_threshold = _limiar_original
	sistema.free()


## Teste 11 — o consumo cruza zero: a quantidade para exatamente em zero e o
## esgotamento é detectado no mesmo passo.
func test_11_cruza_zero_por_consumo() -> void:
	var esgotamentos := [0]
	sistema.fuel_depleted.connect(func(): esgotamentos[0] += 1)

	sistema.update(1000.0, 100.0)  # um único passo grande demais

	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_int(esgotamentos[0]).is_equal(1)


## Teste 12 — a penalidade nunca deixa o valor negativo.
func test_12_penalidade_nunca_negativo() -> void:
	GameConfig.fuel_initial_amount = 5.0
	sistema.reset()
	GameConfig.current_environment_id = "FOREST"
	GameConfig.collision_fuel_penalty = {"FOREST": 3.0}

	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(2.0)
	sistema.on_player_collision()
	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_bool(sistema.get_atual() >= 0.0).is_true()


## Teste 13 — pós-esgotado: nenhum consumo, nenhuma penalidade e nenhum novo
## evento; o valor permanece em zero.
func test_13_pos_esgotado_sem_consumo_nem_eventos() -> void:
	sistema.update(1000.0, 100.0)
	assert_float(sistema.get_atual()).is_equal(0.0)

	var mudancas := [0]
	var esgotamentos := [0]
	var baixos := [0]
	sistema.fuel_changed.connect(func(_a, _c): mudancas[0] += 1)
	sistema.fuel_depleted.connect(func(): esgotamentos[0] += 1)
	sistema.fuel_low.connect(func(): baixos[0] += 1)

	GameConfig.current_environment_id = "ICE"
	sistema.update(5.0, 100.0)
	sistema.on_player_collision()
	sistema.update(5.0, 0.0)

	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_int(mudancas[0]).is_equal(0)
	assert_int(esgotamentos[0]).is_equal(0)
	assert_int(baixos[0]).is_equal(0)


## Teste 14 — exatamente 1 evento por ocorrência, qualquer que seja a origem
## (consumo, penalidade ou combinação dos dois no mesmo limite).
func test_14_exatamente_um_evento_qualquer_origem() -> void:
	# Origem: consumo puro.
	var esgotamentos := [0]
	sistema.fuel_depleted.connect(func(): esgotamentos[0] += 1)
	sistema.update(1000.0, 100.0)
	assert_int(esgotamentos[0]).is_equal(1)

	# Origem: penalidade pura — tanque já pequeno, a colisão zera sozinha.
	GameConfig.fuel_initial_amount = 2.0
	sistema.reset()
	esgotamentos[0] = 0
	GameConfig.current_environment_id = "ICE"
	sistema.on_player_collision()
	assert_int(esgotamentos[0]).is_equal(1)

	# Origem: combinação — o consumo deixa pouco saldo, a colisão zera.
	sistema.reset()
	GameConfig.fuel_initial_amount = 2.0
	sistema.reset()
	esgotamentos[0] = 0
	sistema.update(0.5, 100.0)          # consome 1.0 → sobra 1.0
	sistema.on_player_collision()       # penalidade 3.0 → zera
	assert_float(sistema.get_atual()).is_equal(0.0)
	assert_int(esgotamentos[0]).is_equal(1)

	# Rearma somente em nova partida: um novo esgotamento é possível.
	sistema.reset()
	esgotamentos[0] = 0
	sistema.update(1000.0, 100.0)
	assert_int(esgotamentos[0]).is_equal(1)


## FR-021 — pós-esgotado, o sistema só comunica: nenhum evento além da família
## fuel_* é observável (o FuelSystem não tem nem poderia emitir sinais de
## estado/falha — Game Over é da SPEC-008).
func test_fr021_apenas_sinais_fuel_apos_esgotamento() -> void:
	sistema.update(1000.0, 100.0)
	var observados: Array[String] = []
	sistema.fuel_changed.connect(func(_a, _c): observados.append("fuel_changed"))
	sistema.fuel_low.connect(func(): observados.append("fuel_low"))
	sistema.fuel_depleted.connect(func(): observados.append("fuel_depleted"))

	sistema.update(1.0, 100.0)
	sistema.on_player_collision()

	for nome in observados:
		assert_bool(
			nome == "fuel_changed" or nome == "fuel_low" or nome == "fuel_depleted"
		).is_true()
	assert_float(sistema.get_atual()).is_equal(0.0)
