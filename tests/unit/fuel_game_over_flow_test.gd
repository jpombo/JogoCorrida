extends GdUnitTestSuite

## SPEC-008 / teste obrigatório G (esgotado + coleta) — US4.
## Flag de bloqueio de aceleração derivada do valor atual (R5, SC-007):
## desaceleração natural preservada, GAME_OVER exatamente 1× por corrida
## (SC-005), restauração em PLAYING desbloqueia sem latch (Clarificação) e
## restauração em GAME_OVER não reativa a corrida.

var gm: GameplayManager
var controller: VehicleController

var _cap_original: float
var _inicial_original: float

## Contadores de sinal — vars de membro (lambdas capturam int por valor).
var _derrotas: int = 0
var _vitorias: int = 0


func before_test() -> void:
	_cap_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0

	_derrotas = 0
	_vitorias = 0
	controller = VehicleController.new()
	gm = GameplayManager.new()
	gm.game_state = GameState
	gm.fuel_system = FuelSystem.new()
	gm.track_manager = TrackManager.new()
	gm.player_vehicle = PlayerVehicle.new()
	gm.track_manager.setup(5.0)
	gm.track_manager.reset()
	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()
	GameState.reset()


func after_test() -> void:
	GameConfig.fuel_capacity = _cap_original
	GameConfig.fuel_initial_amount = _inicial_original
	# VehicleController é RefCounted — sem free().
	gm.fuel_system.free()
	gm.track_manager.free()
	gm.player_vehicle.free()
	gm.free()
	GameState.reset()


func _contar_derrota() -> void:
	_derrotas += 1


func _contar_vitoria() -> void:
	_vitorias += 1


## G1 — com o bloqueio ativo a desaceleração natural continua valendo: o
## carro NÃO para instantaneamente (FR-015, SC-007).
func test_g1_desaceleracao_gradual_com_bloqueio() -> void:
	controller.speed = 50.0
	controller.aceleracao_bloqueada_por_combustivel = true
	controller._process(0.1)  # sem input ⇒ desaceleração natural 15 un/s
	assert_float(controller.speed).is_equal_approx(50.0 - GameConfig.natural_deceleration * 0.1, 0.0001)
	assert_bool(controller.speed > 0.0).is_true()


## G2 — reset limpa a flag junto com o restante do estado (R10).
func test_g2_reset_limpa_flag() -> void:
	controller.aceleracao_bloqueada_por_combustivel = true
	controller.reset()
	assert_bool(controller.aceleracao_bloqueada_por_combustivel).is_false()
	assert_float(controller.speed).is_equal(0.0)


## G3 — GAME_OVER exatamente 1× por corrida (SC-005/SC-007): combustível
## zero, parado e sem concluir ⇒ 1×; repetir a avaliação não duplica.
func test_g3_game_over_uma_vez() -> void:
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 0.0

	gm.race_lost.connect(_contar_derrota)
	gm.race_won.connect(_contar_vitoria)

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(_derrotas).is_equal(1)
	assert_int(_vitorias).is_equal(0)
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)

	gm._avaliar_transicoes()
	assert_int(_derrotas).is_equal(1)
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)


## G4 — ainda em movimento com combustível zero NÃO é GAME_OVER: a parada é
## condição necessária (FR-016) — a desaceleração leva tempo (FR-015).
func test_g4_andando_sem_game_over() -> void:
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 30.0

	gm.race_lost.connect(_contar_derrota)
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(_derrotas).is_equal(0)
	assert_int(GameState.current_state).is_equal(GameState.State.PLAYING)


## G5 — restaurar em PLAYING desbloqueia na hora: a flag deriva do valor
## atual, sem latch (Clarificação, R5) — coleta durante a desaceleração
## reativa a aceleração (passo manual 7).
func test_g5_restaurar_desbloqueia() -> void:
	# Esgota de verdade (latch de depletion armado — sem rearme).
	while gm.fuel_system.get_atual() > 0.0:
		gm.fuel_system.update(1.0, 100.0)
	assert_float(gm.fuel_system.get_atual()).is_equal(0.0)

	# Coleta: valor volta a ser positivo ⇒ o predicado de bloqueio é falso.
	gm.fuel_system.restaurar(GameConfig.fuel_can_restore_amount)
	assert_bool(gm.fuel_system.get_atual() > 0.0).is_true()
	var bloqueado: bool = gm.fuel_system.get_atual() <= 0.0
	assert_bool(bloqueado).is_false()


## G6 — restaurar em GAME_OVER não reativa a corrida (GAME_OVER nunca é
## revertido — R9): nenhum evento novo de fim, estado permanece.
func test_g6_restaurar_em_game_over_nao_reativa() -> void:
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 0.0
	gm.race_lost.connect(_contar_derrota)
	gm.race_won.connect(_contar_vitoria)

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)

	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()  # só o valor muda; a corrida já encerrou
	gm._avaliar_transicoes()
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)
	assert_int(_derrotas).is_equal(1)
	assert_int(_vitorias).is_equal(0)
