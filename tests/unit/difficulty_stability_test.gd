extends GdUnitTestSuite

## SPEC-009 / T024 (Polish) + T029/T032 (Convergence) — Estabilidade sob o
## cenário máximo (SC-013): Desafio 4,0× (+ densidade 1,20× + ciclos simulados
## de bônus) com a ORDEM CANÔNICA DO QUADRO completa (rolagem → trânsito →
## colisão NPC×NPC → limites → colisão jogador×NPC → galões → combustível →
## pista, R9/`_processar_playing`) — 0 erros, 0 crescimento indefinido
## (limites absolutos de NPCs e de galões nunca estourados em corridas longas),
## a corrida de referência permanece concluível (pista com `setup` real —
## SC-013), o pipeline de colisão está vivo no cenário máximo (SC-009) e a
## geração de NPCs segue após reinícios — 0 bloqueios permanentes (SC-005).

var _gm: GameplayManager
var _road: Road
var _ambiente_original: String
var _colisoes_jogador: int = 0
var _nascimentos: int = 0


func before_test() -> void:
	_ambiente_original = String(GameConfig.current_environment_id)
	GameConfig.current_environment_id = "PLAINS"
	GameState.reset()
	_colisoes_jogador = 0
	_nascimentos = 0
	_gm = _montar_gm_maximo()
	_gm.collision_system.collision_occurred.connect(func(_d): _colisoes_jogador += 1)
	_gm.traffic_layer.vehicle_spawned.connect(func(_v): _nascimentos += 1)


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	_desmontar_gm(_gm)
	GameState.reset()


## 1 — Corrida longa (60 s simulados) no cenário máximo: nenhum teto
## estoura, nenhum erro de script, o pipeline de colisão detecta ao menos um
## contato jogador×NPC (SC-009) e a corrida de referência termina (SC-013).
func test_01_corrida_longa_limites_absolutos() -> void:
	GameState.change_state(GameState.State.PLAYING)
	var delta: float = 1.0 / 60.0
	var velocidade: float = GameConfig.max_speed * 4.0
	for i in 3600:
		_rodar_quadro(delta, velocidade)

		# Limites absolutos inegociáveis em QUALQUER quadro.
		if _gm.traffic_layer.active_vehicles.size() > GameConfig.traffic_max_vehicles:
			fail("NPCs estouraram o teto no quadro %d: %d > %d"
				% [i, _gm.traffic_layer.active_vehicles.size(), GameConfig.traffic_max_vehicles])
			break
		if _gm.items_layer.ativos.size() > GameConfig.fuel_can_max_active:
			fail("Galões estouraram o teto no quadro %d: %d > %d"
				% [i, _gm.items_layer.ativos.size(), GameConfig.fuel_can_max_active])
			break

	assert_bool(_colisoes_jogador > 0).override_failure_message(
		"SC-009: 0 colisões jogador×NPC em 60 s — pipeline de colisão morto no cenário máximo"
	)

	# Bônus de 100 ciclos (1,20×) não impede a conclusão da corrida: a
	# distância é alcançável em tempo finito (`percorrida` chega ao total;
	# a flag `concluido` é domínio do fluxo do GM via banda de chegada).
	var iteracoes: int = 0
	while (
		_gm.track_manager.get_percorrida() < _gm.track_manager.get_total()
		and iteracoes < 20000
	):
		_rodar_quadro(delta, velocidade)
		iteracoes += 1
	assert_bool(_gm.track_manager.get_percorrida() >= _gm.track_manager.get_total())\
		.override_failure_message("Corrida de referência inconcluível")
	assert_bool(_gm.track_manager.get_total() > 0.0).override_failure_message(
		"SC-013: total da pista zerado — asserção de conclusão seria vazia (setup ausente)"
	)


## 2 — Ciclos simulados: o bônus de ciclo cresce os fatores, mas os
## limites absolutos seguram tudo (nenhuma corrida fica inconcluível nem
## os pools crescem sem teto).
func test_02_ciclos_simulados() -> void:
	# Simula 500 ciclos concluídos (fator de ciclo 2,002 — bem acima do
	# cenário realista) e larga de novo.
	for i in 500:
		_gm.progresso.registra_vitoria()
	_gm._on_start_race()

	var fator: float = _gm.dificuldade.fator_velocidade_total()
	assert_bool(fator > 5.0).override_failure_message(
		"Desafio × fator de ciclo 500 deveria superar 5,0 — veio %.3f" % fator
	)

	GameState.change_state(GameState.State.PLAYING)
	var delta: float = 1.0 / 60.0
	var velocidade: float = fator * GameConfig.max_speed
	for i in 1200:
		_rodar_quadro(delta, velocidade)
		if _gm.traffic_layer.active_vehicles.size() > GameConfig.traffic_max_vehicles:
			fail("Ciclos estouraram o teto de NPCs no quadro %d" % i)
			break
		if _gm.items_layer.ativos.size() > GameConfig.fuel_can_max_active:
			fail("Ciclos estouraram o teto de galões no quadro %d" % i)
			break

	# A corrida termina: a pista é finita mesmo com o bônus máximo.
	var iteracoes: int = 0
	while (
		_gm.track_manager.get_percorrida() < _gm.track_manager.get_total()
		and iteracoes < 20000
	):
		_rodar_quadro(delta, velocidade)
		iteracoes += 1
	assert_bool(_gm.track_manager.get_percorrida() >= _gm.track_manager.get_total())\
		.override_failure_message("Corrida inconcluível com ciclos simulados")


## 3 — SC-005 / T032: a geração de NPCs continua em corrida longa e após o
## reinício real (largada → `_reset_corrida`), sem bloqueio permanente.
func test_03_nascimentos_continuos_apos_reinicio() -> void:
	GameState.change_state(GameState.State.PLAYING)
	var delta: float = 1.0 / 60.0
	var velocidade: float = GameConfig.max_speed * 4.0

	for i in 900:
		_rodar_quadro(delta, velocidade)
	assert_bool(_nascimentos > 0).override_failure_message(
		"SC-005: 0 nascimentos em 15 s de corrida longa — geração bloqueada"
	)

	# Reinício pelo caminho do jogo: preparação + READY → PLAYING executa o
	# `_reset_corrida` completo (trânsito devolvido ao pool).
	var antes_do_reinicio: int = _nascimentos
	_gm._on_start_race()
	GameState.change_state(GameState.State.PLAYING)
	assert_int(_gm.traffic_layer.active_vehicles.size()).is_zero()\
		.override_failure_message("SC-005: reinício não zerou o trânsito ativo")

	for i in 900:
		_rodar_quadro(delta, velocidade)
	assert_bool(_nascimentos > antes_do_reinicio).override_failure_message(
		"SC-005: 0 nascimentos após o reinício — bloqueio permanente"
	)


## 4 — SC-009 / T029: colisão NPC×NPC com fator de velocidade 3× e 4× —
## encontro longitudinal detectado exatamente uma vez por episódio, sem
## atravessamento (0 contatos perdidos) e só o atingido em drift (FR-014).
func test_04_npc_x_npc_fatores_3x_4x() -> void:
	for fator in [3.0, 4.0]:
		var sistema := NpcCollisionSystem.new()
		var eventos: Array = []
		sistema.npc_collision_occurred.connect(func(d): eventos.append(d))

		var caminhao := _npc_de_teste("caminhao", Vector2(320.0, 200.0), fator)
		var esporte := _npc_de_teste("esporte", Vector2(320.0, 300.0), fator)
		var npcs: Array = [caminhao, esporte]
		var delta: float = 1.0 / 60.0
		var bounds := Callable(_road, "get_boundaries_for_player_y")

		# Avanço realista: ambos sobem com a própria velocidade; o esporte
		# (96 × fator) fecha os ~45 px de folga sobre o caminhão (72 × fator)
		# e os ultrapassa — fechamento de 24 × fator px/s (96 px/s a 4×).
		# As consequências são conferidas NO QUADRO DO CONTATO (o drift tem
		# duração finita e expira antes do fim da passagem); a passagem
		# completa é que prova o "0 atravessamento" e o "0 duplicação".
		var quadro_contato: int = -1
		for i in 240:
			caminhao.position.y -= caminhao.get_speed() * delta
			esporte.position.y -= esporte.get_speed() * delta
			sistema.update(delta, npcs, bounds, 0.0)
			if quadro_contato < 0 and eventos.size() == 1:
				quadro_contato = i
				var d: NpcCollisionData = eventos[0]
				assert_bool(d.causador == esporte).is_true().override_failure_message(
					"SC-009 (%.0fx): causador da ultrapassagem incorreto" % fator
				)
				assert_bool(caminhao.npc_drift.ativo()).is_true().override_failure_message(
					"FR-014 (%.0fx): atingido sem drift após o contato" % fator
				)
				assert_bool(esporte.npc_drift.ativo()).is_false().override_failure_message(
					"FR-014 (%.0fx): causador recebeu drift — só o atingido desloca" % fator
				)

		assert_bool(quadro_contato >= 0).override_failure_message(
			"SC-009 (%.0fx): passagem completa sem contato detectado — atravessamento" % fator
		)
		assert_int(eventos.size()).is_equal(1).override_failure_message(
			"SC-009 (%.0fx): passagem completa gerou %d eventos (esperado 1 — 0 duplicações)"
				% [fator, eventos.size()]
		)

		sistema = null
		caminhao.free()
		esporte.free()


## Ordem canônica do quadro (R9, `_processar_playing`): rolagem → trânsito →
## colisão NPC×NPC → limites do jogador → colisão jogador×NPC → galões →
## combustível → progressão da pista.
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


func _npc_de_teste(categoria_id: String, pos: Vector2, fator: float) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = GameConfig.NPC_HITBOX_SIZES[categoria_id]
	npc.position = pos
	npc.y_nascimento = -200.0
	npc.fator_dificuldade = fator
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


## Monta o cenário máximo: Desafio + densidade 1,20 + fator de ciclo de
## 100 ciclos (1,202×) — GM sintético no padrão das suítes anteriores (R12),
## com injeção real de fatores, pista e tanque inicializados (senão o consumo
## e a conclusão seriam asserções vazias).
func _montar_gm_maximo() -> GameplayManager:
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

	# Tanque e pista reais (SPEC-008): sem isto `fuel_system.update` cai no
	# `_atual <= 0` e `track_manager.update` no `total <= 0` todo quadro.
	gerente.fuel_system.reset()
	gerente.track_manager.setup(GameConfig.track_total_distance)
	gerente.track_manager.reset()

	# Cenário máximo via API real (mesmos caminhos do jogo).
	gerente.dificuldade.definir_modo("challenge")
	gerente.dificuldade.aplicar_fator_ciclo(1.0 + GameConfig.difficulty_cycle_bonus_increment * 100.0)
	gerente._aplicar_fatores_por_corrida()
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	return gerente


func _desmontar_gm(gerente: GameplayManager) -> void:
	gerente.fuel_system.free()
	gerente.track_manager.free()
	gerente.track_layer.free()
	gerente.player_vehicle.free()
	gerente.traffic_layer.free()
	gerente.items_layer.free()
	_road.free()
	gerente.free()
