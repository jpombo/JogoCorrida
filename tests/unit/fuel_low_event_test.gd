extends GdUnitTestSuite

## SPEC-007 / US4 — teste obrigatório 15: detecção de combustível baixo.
## Latch por partida (contract fuel_events.md §2): travessia emite 1×, sem
## repetência enquanto persistir; init já abaixo do limiar sinaliza desde o
## `reset()` (borda 15) sem duplicar.

var sistema: FuelSystem

var _capacidade_original: float
var _inicial_original: float
var _limiar_original: float
var _ambiente_original: String


func before_test() -> void:
	_capacidade_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_limiar_original = GameConfig.fuel_low_threshold
	_ambiente_original = GameConfig.current_environment_id
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0
	GameConfig.fuel_low_threshold = 0.2
	sistema = FuelSystem.new()


func after_test() -> void:
	GameConfig.fuel_capacity = _capacidade_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_low_threshold = _limiar_original
	GameConfig.current_environment_id = _ambiente_original
	sistema.free()


## Travessia por consumo: emite fuel_low exatamente 1× e o estado derivado
## acompanha; permanecer abaixo não repete o evento.
func test_15_travessia_do_limiar_emite_uma_vez() -> void:
	var baixos := [0]
	sistema.reset()
	sistema.fuel_low.connect(func(): baixos[0] += 1)

	assert_bool(sistema.esta_baixo()).is_false()
	assert_int(baixos[0]).is_equal(0)

	# 98 s a 2 u/s ⇒ drena até cruzar o limiar de 20 u (capacidade 100).
	for i in 98:
		sistema.update(1.0, 100.0)

	assert_bool(sistema.get_atual() <= 0.2 * 100.0).is_true()
	assert_bool(sistema.esta_baixo()).is_true()
	assert_int(baixos[0]).is_equal(1)

	# Continua abaixo: nenhuma repetência.
	for i in 20:
		sistema.update(1.0, 100.0)
	assert_int(baixos[0]).is_equal(1)
	assert_bool(sistema.esta_baixo()).is_true()


## Travessia por penalidade de colisão também sinaliza (origem indiferente).
func test_15b_travessia_por_penalidade_emite_uma_vez() -> void:
	var baixos := [0]
	GameConfig.fuel_initial_amount = 21.0
	sistema.reset()
	sistema.fuel_low.connect(func(): baixos[0] += 1)
	assert_bool(sistema.esta_baixo()).is_false()

	GameConfig.current_environment_id = "ICE"
	sistema.on_player_collision()  # -3 ⇒ 18 ≤ 20

	assert_bool(sistema.esta_baixo()).is_true()
	assert_int(baixos[0]).is_equal(1)


## Borda 15 — valor inicial já abaixo do limiar sinaliza desde o `reset()`,
## exatamente uma vez; updates seguintes não duplicam.
func test_15c_init_abaixo_do_limiar_sinaliza_sem_duplicar() -> void:
	GameConfig.fuel_initial_amount = 10.0
	var baixos := [0]
	sistema.fuel_low.connect(func(): baixos[0] += 1)  # connect ANTES do reset

	sistema.reset()

	assert_bool(sistema.esta_baixo()).is_true()
	assert_int(baixos[0]).is_equal(1)
	for i in 5:
		sistema.update(1.0, 100.0)
	assert_int(baixos[0]).is_equal(1)


## Limiar configurável: outro threshold move a fronteira sem tocar em lógica.
func test_15d_limiar_configuravel() -> void:
	GameConfig.fuel_low_threshold = 0.5
	GameConfig.fuel_initial_amount = 60.0
	sistema.reset()
	var baixos := [0]
	sistema.fuel_low.connect(func(): baixos[0] += 1)
	assert_bool(sistema.esta_baixo()).is_false()

	for i in 10:
		sistema.update(1.0, 100.0)  # 60 → 40 ≤ 50
	assert_bool(sistema.esta_baixo()).is_true()
	assert_int(baixos[0]).is_equal(1)


## Guard de divisão: capacidade zero não pode emitir nem travar (borda 6).
func test_15e_capacidade_zero_sem_emissao() -> void:
	GameConfig.fuel_capacity = 0.0
	var baixos := [0]
	sistema.reset()
	sistema.fuel_low.connect(func(): baixos[0] += 1)

	sistema.update(1.0, 100.0)
	assert_int(baixos[0]).is_equal(0)
	assert_bool(sistema.esta_baixo()).is_false()
	assert_float(sistema.get_atual()).is_equal(0.0)
