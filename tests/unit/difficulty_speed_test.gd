extends GdUnitTestSuite

## SPEC-009 / T004 (US1) — velocidade do modo: jogador e NPCs 1×/3×/4×
## (SC-001/SC-002), bases nunca mutadas (FR-003), 5 reinícios sem acúmulo,
## curva normalizada coincidente e timers de largada inalterados (SC-003),
## distância idêntica nos 3 modos (SC-004) e colisão detectada em 3×/4×
## com penalidade aplicada uma única vez (SC-009, FR-014; R4 — sem
## substepping).

const ACOES: Array[String] = ["accelerate", "brake", "move_left", "move_right"]
const FATOR_PADRAO: float = 1.0


func before_test() -> void:
	_soltar_acoes()
	GameState.reset()


func after_test() -> void:
	_soltar_acoes()
	GameState.reset()


func _soltar_acoes() -> void:
	for acao in ACOES:
		Input.action_release(acao)


func _npc(categoria_id: String, pos: Vector2, fator: float) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = Vector2(32.0, 48.0)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	npc.fator_dificuldade = fator
	return npc


func _bounds(_y: float) -> Dictionary:
	return {"left": 248.0, "right": 392.0}


## SC-001 — teto do jogador exatamente max_speed × fator em 1×/3×/4×.
func test_01_jogador_teto_1x_3x_4x() -> void:
	for fator in [1.0, 3.0, 4.0]:
		var controller := VehicleController.new()
		controller.fator_dificuldade = fator
		Input.action_press("accelerate")
		controller.speed = 0.0
		for i in 200:
			controller._process(1.0 / 60.0)
		Input.action_release("accelerate")
		assert_float(controller.speed).is_equal_approx(
			GameConfig.max_speed * fator, 0.001
		).override_failure_message("Teto em fator %.1f" % fator)
		controller.reset()
		# reset() não toca no fator (contrato §4: reinício reaplica via config).
		assert_float(controller.fator_dificuldade).is_equal(fator)
		controller.fator_dificuldade = FATOR_PADRAO


## SC-001 — aceleração/frenagem/desaceleração escaladas juntas do teto
## (razões preservadas — R2).
func test_02_aceleracao_frenagem_decel_proporcionais() -> void:
	for fator in [1.0, 3.0, 4.0]:
		var controller := VehicleController.new()
		controller.fator_dificuldade = fator

		Input.action_press("accelerate")
		controller.speed = 0.0
		controller._process(0.1)
		assert_float(controller.speed).is_equal_approx(
			GameConfig.acceleration * fator * 0.1, 0.0001
		)
		Input.action_release("accelerate")

		controller.speed = 100.0 * fator
		Input.action_press("brake")
		controller._process(0.1)
		assert_float(controller.speed).is_equal_approx(
			100.0 * fator - GameConfig.brake_force * fator * 0.1, 0.001
		)
		Input.action_release("brake")

		controller.speed = 100.0 * fator
		controller._process(0.1)  # nenhuma ação → desaceleração natural
		assert_float(controller.speed).is_equal_approx(
			100.0 * fator - GameConfig.natural_deceleration * fator * 0.1, 0.001
		)
		controller.fator_dificuldade = FATOR_PADRAO


## SC-003 — a curva normalizada speed/(max × fator) coincide nos 3 modos.
func test_03_curva_normalizada_coincidente() -> void:
	var trajetorias: Dictionary = {}
	for fator in [1.0, 3.0, 4.0]:
		var controller := VehicleController.new()
		controller.fator_dificuldade = fator
		Input.action_press("accelerate")
		controller.speed = 0.0
		var trajetoria: Array[float] = []
		for i in 20:
			controller._process(0.1)
			trajetoria.append(controller.speed / (GameConfig.max_speed * fator))
		Input.action_release("accelerate")
		trajetorias[fator] = trajetoria
		controller.fator_dificuldade = FATOR_PADRAO

	for i in 20:
		assert_float(trajetorias[3.0][i]).is_equal_approx(trajetorias[1.0][i], 0.0001)
		assert_float(trajetorias[4.0][i]).is_equal_approx(trajetorias[1.0][i], 0.0001)


## SC-003 — posição vertical normalizada pelo teto efetivo: mesma razão de
## velocidade ⇒ mesma altura em qualquer modo.
func test_04_posicao_vertical_normalizada() -> void:
	var controller := VehicleController.new()
	controller.fator_dificuldade = 4.0
	controller.speed = GameConfig.max_speed * 4.0
	assert_float(controller.get_vertical_position()).is_equal_approx(
		GameConfig.vertical_position_min, 0.0001
	)
	controller.speed = GameConfig.max_speed * 4.0 * 0.5
	var meio_4x: float = controller.get_vertical_position()
	controller.fator_dificuldade = FATOR_PADRAO
	controller.speed = GameConfig.max_speed * 0.5
	assert_float(meio_4x).is_equal_approx(controller.get_vertical_position(), 0.0001)


## SC-002 — NPCs: 4 categorias × 3 fatores; bases 90/90/100/120 km/h nunca
## mutadas (FR-003 — TRAFFIC_CATEGORIES e TrafficData intactos).
func test_05_npcs_4_categorias_1x_3x_4x() -> void:
	var esperados_kmh := {
		"caminhao": 90.0, "utilitario": 90.0, "passeio": 100.0, "esporte": 120.0,
	}
	for categoria_id in esperados_kmh:
		var base: float = esperados_kmh[categoria_id] * GameConfig.KMH_TO_SPEED_UNIT
		for fator in [1.0, 3.0, 4.0]:
			var npc := _npc(categoria_id, Vector2.ZERO, fator)
			assert_float(npc.get_speed()).is_equal_approx(
				base * fator, 0.0001
			).override_failure_message("%s em fator %.1f" % [categoria_id, fator])
			# Base da config intocada após a leitura.
			assert_float(
				float(GameConfig.TRAFFIC_CATEGORIES[categoria_id]["max_speed_kmh"])
			).is_equal(esperados_kmh[categoria_id])
			npc.free()
	assert_float(float(GameConfig.TRAFFIC_CATEGORIES["passeio"]["max_speed_kmh"])).is_equal(100.0)


## 5 reinícios sem acúmulo: a 5ª largada em 4× é idêntica à 1ª (FR-003).
func test_06_cinco_reinicios_sem_acumulo() -> void:
	var controller := VehicleController.new()
	controller.fator_dificuldade = 4.0
	Input.action_press("accelerate")
	for corrida in 5:
		controller.reset()
		controller.speed = 0.0
		for i in 200:
			controller._process(1.0 / 60.0)
		assert_float(controller.speed).is_equal_approx(
			GameConfig.max_speed * 4.0, 0.001
		).override_failure_message("Corrida %d sem acúmulo" % (corrida + 1))
	Input.action_release("accelerate")
	controller.fator_dificuldade = FATOR_PADRAO


## SC-003 — contagem de largada de 1 s inalterada pelo modo: o timer do
## READY → PLAYING não escala com o fator de dificuldade.
func test_07_contagem_largada_nao_escala() -> void:
	var gm := GameplayManager.new()
	add_child(gm)
	# Injeta o fator máximo nos componentes que existem como campo do manager
	# — nenhum deles pode encurtar/alongar o timer literal de 1 s.
	gm.fuel_system.fator_velocidade = 4.0
	gm.fuel_system.fator_penalidade_colisao = 1.5
	GameState.change_state(GameState.State.READY)
	var inicio_ms: int = Time.get_ticks_msec()
	await gm._aguardar_inicio()
	var decorrido: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0
	assert_float(decorrido).is_greater_equal(0.8).override_failure_message(
		"Contagem de largada encurtada: %.2f s" % decorrido
	)
	assert_float(decorrido).is_less(1.6).override_failure_message(
		"Contagem de largada alongada: %.2f s" % decorrido
	)
	gm.free()
	GameState.reset()


## SC-004 — distância: total idêntico nos 3 modos, percorrida nunca acima
## do total e zero acréscimo com a estrada parada (FR-007).
func test_08_distancia_total_identica_nos_modos() -> void:
	for fator in [1.0, 3.0, 4.0]:
		var track := TrackManager.new()
		track.setup(5.0)
		track.reset()
		assert_float(track.get_total()).is_equal(5.0)

		var velocidade: float = GameConfig.max_speed * fator
		for i in 1200:  # 20 s
			track.update(1.0 / 60.0, velocidade)
		assert_float(track.get_percorrida()).is_less_equal(5.0 + 0.0001)

		# 0 acréscimos por temporizadores/estados: parado, nada avança.
		var parada: float = track.get_percorrida()
		track.update(1.0, 0.0)
		assert_float(track.get_percorrida()).is_equal(parada)
		track.free()


## SC-009 / FR-014 — colisão detectada no mesmo encontro em 3× e 4×:
## 0 atravessamentos (exatamente 1 evento por passagem completa) e a
## penalidade de combustível aplicada uma única vez por evento.
func test_09_colisao_em_3x_e_4x_penalidade_unica() -> void:
	var penalidade_ambiente: float = 3.0  # FOREST/ICE
	GameConfig.current_environment_id = "FOREST"
	for fator in [3.0, 4.0]:
		var sistema := CollisionSystem.new()
		var jogador := PlayerVehicle.new()
		jogador.position = Vector2(320.0, 400.0)
		jogador.controller.speed = GameConfig.max_speed * fator

		var fuel := FuelSystem.new()
		fuel.fator_penalidade_colisao = fator
		fuel.reset()

		var npc := _npc("passeio", Vector2(320.0, 200.0), fator)
		var eventos: Array = []
		sistema.collision_occurred.connect(func(d): eventos.append(d))
		sistema.collision_occurred.connect(fuel.on_player_collision)

		var antes: float = fuel.get_atual()
		# Passagem completa: o NPC desce pela diferença de velocidade — ambos
		# escalam com o fator, a janela de detecção acompanha (R4).
		var relativa: float = (GameConfig.max_speed * fator - npc.get_speed()) / 60.0
		var passou_completamente: bool = false
		for i in 800:
			npc.position.y += relativa
			sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
			if npc.position.y - 24.0 > jogador.position.y + 22.0:
				passou_completamente = true
				break

		assert_bool(passou_completamente).is_true()
		assert_int(eventos.size()).is_equal(1).override_failure_message(
			"Encontro em fator %.1f gerou %d eventos (esperado 1 — sem atravessamento)"
			% [fator, eventos.size()]
		)
		assert_float(fuel.get_atual()).is_equal_approx(
			antes - penalidade_ambiente * fator, 0.001
		).override_failure_message(
			"Penalidade em fator %.1f aplicada fora de 1×" % fator
		)

		npc.free()
		jogador.free()
		fuel.free()
	GameConfig.current_environment_id = "PLAINS"
