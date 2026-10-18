extends GdUnitTestSuite

## SPEC-009 / T025 (Polish) — Fluxo de estados por modo (SC-010):
## MENU/READY/PLAYING/PAUSED/VICTORY/GAME_OVER funcionam em cada um dos
## 3 modos; pausa/retomada alteram o multiplicador em 0 ensaios; o
## reinício reaplica a configuração em 100% dos casos.

var _gm: GameplayManager
var _ambiente_original: String


func before_test() -> void:
	_ambiente_original = String(GameConfig.current_environment_id)
	GameConfig.current_environment_id = "PLAINS"
	GameState.reset()
	_gm = _montar_gm()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	_desmontar_gm(_gm)
	GameState.reset()


## SC-010 — a cadeia completa de estados funciona nos 3 modos: largada,
## jogar, pausar, retomar, vitória, continuar, derrota e volta ao menu.
func test_01_cadeia_completa_nos_3_modos() -> void:
	for modo in ["relaxing", "normal", "challenge"]:
		_gm.dificuldade.definir_modo(modo)

		_gm._on_start_race()
		assert_int(GameState.current_state).is_equal(GameState.State.READY)

		GameState.begin_playing()
		assert_int(GameState.current_state).is_equal(GameState.State.PLAYING)

		GameState.pause_game()
		assert_int(GameState.current_state).is_equal(GameState.State.PAUSED)

		GameState.begin_playing()
		assert_int(GameState.current_state).is_equal(GameState.State.PLAYING)

		# Vitória + continuar (mesma sequência do fluxo real).
		_preparar_vitoria()
		GameState.change_state(GameState.State.PLAYING)
		_gm._avaliar_transicoes()
		assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)
		_gm._on_continue_next_phase()
		assert_int(GameState.current_state).is_equal(GameState.State.READY)

		# Derrota a partir da nova corrida.
		GameState.begin_playing()
		_gm.fuel_system.definir_capacidade_derivada(0.0)
		_gm.fuel_system.reset()
		_gm.player_vehicle.controller.speed = 0.0
		_gm._avaliar_transicoes()
		assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)

		_gm._on_go_to_menu()
		assert_int(GameState.current_state).is_equal(GameState.State.MENU)


## SC-010 — 50 ensaios de pausa/retomada por modo (150 total): 0 mudanças
## no multiplicador efetivo e 0 mudanças nos fatores injetados.
func test_02_pausa_retomada_zero_mudancas() -> void:
	for modo in ["relaxing", "normal", "challenge"]:
		_gm.dificuldade.definir_modo(modo)
		_gm._on_start_race()
		GameState.begin_playing()

		var fator_antes: float = _gm.dificuldade.fator_velocidade_total()
		var injetado_antes: float = _gm.fuel_system.fator_velocidade

		for i in 50:
			GameState.pause_game()
			GameState.begin_playing()

		assert_float(_gm.dificuldade.fator_velocidade_total()).is_equal(fator_antes)
		assert_float(_gm.fuel_system.fator_velocidade).is_equal(injetado_antes)


## SC-010 — o reinício reaplica a configuração em 100% dos casos: sujar os
## fatores injetados e reiniciar devolve os valores vigentes do modo.
func test_03_reinicio_reaplica_configuracao() -> void:
	var esperado_por_modo: Dictionary = {
		"relaxing": 1.0, "normal": 3.0, "challenge": 4.0,
	}
	for modo in ["relaxing", "normal", "challenge"]:
		_gm.dificuldade.definir_modo(modo)
		_gm._on_start_race()
		GameState.begin_playing()

		# Sujou os injetados (simula corrupção externa).
		_gm.player_vehicle.controller.fator_dificuldade = 999.0
		_gm.fuel_system.fator_velocidade = 999.0
		_gm.traffic_layer.fator_dificuldade = 999.0

		_gm._on_restart_race()
		var esperado: float = float(esperado_por_modo[modo])

		assert_float(_gm.player_vehicle.controller.fator_dificuldade).is_equal(esperado)
		assert_float(_gm.fuel_system.fator_velocidade).is_equal(esperado)
		assert_float(_gm.traffic_layer.fator_dificuldade).is_equal(esperado)
		assert_int(GameState.current_state).is_equal(GameState.State.READY)


## Prepara vitória (padrão das suítes anteriores): banda cruzada + combustível.
## A banda nasce ABAIXO da posição inicial real do jogador (o `_reset_corrida`
## da largada posiciona o carro — banda fixa em 430 não cruzaria, como no
## track_finish_test que não passa pelo reset).
func _preparar_vitoria() -> void:
	_gm.track_manager.setup(5.0)
	_gm.track_manager.reset()
	_gm.fuel_system.definir_capacidade_derivada(100.0)
	_gm.fuel_system.reset()
	_gm.track_layer.criar_marcadores(
		_gm.player_vehicle.position.y, GameConfig.track_total_distance
	)
	_gm.track_layer.banda_chegada.position.y = (
		_gm.player_vehicle.position.y + GameConfig.player_hitbox_size.y * 0.5 + 10.0
	)


## GM sintético completo no padrão das suítes anteriores (R12).
func _montar_gm() -> GameplayManager:
	var gerente := GameplayManager.new()
	gerente.game_state = GameState
	gerente.fuel_system = FuelSystem.new()
	gerente.track_manager = TrackManager.new()
	gerente.track_layer = TrackMarkers.new()
	gerente.player_vehicle = PlayerVehicle.new()
	gerente.player_vehicle.sprite = Sprite2D.new()
	gerente.traffic_layer = TrafficManager.new()
	gerente.traffic_layer.setup(GameConfig.TRAFFIC_CATEGORIES)
	gerente.items_layer = FuelCanManager.new()
	gerente.items_layer.setup()
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	return gerente


func _desmontar_gm(gerente: GameplayManager) -> void:
	gerente.fuel_system.free()
	gerente.track_manager.free()
	gerente.track_layer.free()
	gerente.player_vehicle.free()
	gerente.traffic_layer.free()
	gerente.items_layer.free()
	gerente.free()
