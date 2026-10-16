extends GdUnitTestSuite

## SPEC-009 / T030 (US4, SC-011) — Corrida de referência automatizada nas 12
## combinações (4 ambientes × 3 modos): a ordem canônica do quadro (rolagem →
## trânsito → colisão NPC×NPC → limites → colisão jogador×NPC → galões →
## combustível → pista) executa sem falha de script em cada combinação, os
## limites absolutos seguram em todos os quadros, a distância avança e a
## injeção de fatores do modo chega aos sistemas dependentes antes da largada
## (FR-016/FR-006 — trocar de modo não altera a corrida em andamento porque a
## injeção acontece uma vez por largada).

var _ambientes: Array[String] = ["PLAINS", "DESERT", "FOREST", "ICE"]
var _modos: Array[String] = ["relaxing", "normal", "challenge"]
var _ambiente_original: String
var _gm: GameplayManager
var _road: Road


func before_test() -> void:
	_ambiente_original = String(GameConfig.current_environment_id)
	GameState.reset()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	_desmontar()
	GameState.reset()


func test_01_12_combinacoes_executam_corrida_de_referencia() -> void:
	var delta: float = 1.0 / 60.0
	for ambiente in _ambientes:
		for modo in _modos:
			_desmontar()
			GameConfig.current_environment_id = ambiente
			GameState.reset()
			_gm = _montar(modo)

			# Injeção no caminho real da largada (mesmo ponto do jogo — R9).
			_gm._aplicar_fatores_por_corrida()
			var fator: float = _gm.dificuldade.fator_velocidade_total()
			assert_float(_gm.player_vehicle.controller.fator_dificuldade).is_equal(fator)\
				.override_failure_message(
					"%s/%s: fator do modo não injetado no jogador (%.3f ≠ %.3f)"
						% [
							ambiente, modo,
							_gm.player_vehicle.controller.fator_dificuldade, fator
						]
				)

			GameState.change_state(GameState.State.PLAYING)
			var velocidade: float = GameConfig.max_speed * fator
			for i in 300:
				_rodar_quadro(delta, velocidade)
				if _gm.traffic_layer.active_vehicles.size() > GameConfig.traffic_max_vehicles:
					fail("%s/%s: NPCs estouraram o teto no quadro %d"
						% [ambiente, modo, i])
					break
				if _gm.items_layer.ativos.size() > GameConfig.fuel_can_max_active:
					fail("%s/%s: galões estouraram o teto no quadro %d"
						% [ambiente, modo, i])
					break

			# Corrida de referência avança de verdade (pista com total real).
			assert_bool(_gm.track_manager.get_percorrida() > 0.0)\
				.override_failure_message(
					"%s/%s: distância não avançou em 300 quadros — corrida de referência morta"
						% [ambiente, modo]
				)

	GameConfig.current_environment_id = _ambiente_original


## Ordem canônica do quadro (R9, `_processar_playing`).
func _rodar_quadro(delta: float, velocidade: float) -> void:
	_road.update_scroll_speed(velocidade)
	_gm.traffic_layer.update(delta, _road)
	_gm.npc_collision_system.update(
		delta,
		_gm.traffic_layer.active_vehicles_snapshot,
		Callable(_road, "get_boundaries_for_player_y"),
		_road.scroll_speed
	)
	var limites: Dictionary = _road.get_boundaries_for_player_y(
		_gm.player_vehicle.position.y
	)
	_gm.player_vehicle.controller.update_boundaries(
		float(limites.left), float(limites.right)
	)
	_gm.collision_system.update(
		delta,
		_gm.player_vehicle,
		_gm.traffic_layer.active_vehicles_snapshot,
		Callable(_road, "get_boundaries_for_player_y")
	)
	_gm.items_layer.update(
		delta, _road, _gm.traffic_layer.active_vehicles_snapshot,
		_gm.track_manager, _gm.player_vehicle
	)
	_gm.fuel_system.update(delta, velocidade)
	_gm.track_manager.update(delta, velocidade)


## GM sintético por combinação — padrão das suítes da SPEC-009 (R12): sem
## `_ready`, com pista e tanque inicializados (senão avanço/consumo seriam
## asserções vazias) e modo aplicado pela API real.
func _montar(modo: String) -> GameplayManager:
	var gerente := GameplayManager.new()
	gerente.game_state = GameState
	gerente.fuel_system = FuelSystem.new()
	gerente.track_manager = TrackManager.new()
	gerente.track_layer = TrackMarkers.new()
	gerente.player_vehicle = PlayerVehicle.new()
	gerente.player_vehicle.sprite = Sprite2D.new()
	gerente.player_vehicle.position = Vector2(320.0, 400.0)
	gerente.traffic_layer = TrafficManager.new()
	gerente.traffic_layer.setup(GameConfig.TRAFFIC_CATEGORIES)
	gerente.items_layer = FuelCanManager.new()
	gerente.items_layer.setup()
	_road = Road.new()
	_road.scroll_speed = GameConfig.scroll_multiplier * GameConfig.max_speed
	gerente.fuel_system.reset()
	gerente.track_manager.setup(GameConfig.track_total_distance)
	gerente.track_manager.reset()
	gerente.dificuldade.definir_modo(modo)
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	return gerente


func _desmontar() -> void:
	if _gm == null:
		return
	_gm.fuel_system.free()
	_gm.track_manager.free()
	_gm.track_layer.free()
	_gm.player_vehicle.free()
	_gm.traffic_layer.free()
	_gm.items_layer.free()
	_road.free()
	_gm.free()
	_gm = null
	_road = null
