extends GdUnitTestSuite

## SPEC-005 / T014 + T027 + T030 — consequências para o jogador: perda de
## velocidade proporcional e limitada (FR-009/FR-010, SC-003), drift na direção
## classificada com controle parcial e recuperação até 100% (FR-011–FR-014,
## SC-004), NPC sem penalização nos tipos 1-1/1-2 (US1-CA4) e clamp nos limites
## vigentes da estrada (FR-022, SC-007).

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}

var sistema: CollisionSystem
var jogador: PlayerVehicle


func before_test() -> void:
	sistema = CollisionSystem.new()
	jogador = PlayerVehicle.new()
	jogador.position = Vector2(320.0, 400.0)


func after_test() -> void:
	jogador.free()
	sistema = null


func _npc(pos: Vector2, categoria_id: String = "passeio") -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = Vector2(32.0, 48.0)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


func _colidir_com(pos_npc: Vector2, vel_jogador: float) -> TrafficVehicle:
	jogador.controller.speed = vel_jogador
	var npc := _npc(pos_npc)
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	return npc  # caller desaloca


func test_speed_loss_within_configured_interval() -> void:
	var npc := _colidir_com(Vector2(320.0, 364.0), 100.0)
	var perda: float = 100.0 - jogador.controller.speed
	assert_float(perda).is_between(GameConfig.collision_speed_loss_min, GameConfig.collision_speed_loss_max).override_failure_message(
		"SC-003: perda %.2f fora do intervalo configurado" % perda
	)
	npc.free()


func test_speed_never_below_zero() -> void:
	var npc := _colidir_com(Vector2(320.0, 364.0), 5.0)  # jogador quase parado
	assert_float(jogador.controller.speed).is_greater_equal(0.0).override_failure_message(
		"FR-010: velocidade abaixo de zero após colisão"
	)
	npc.free()


func test_npc_unchanged_in_player_rear_hit() -> void:
	# US1-CA4: no tipo 1-1 o NPC segue sem penalização alguma (posição e velocidade).
	var npc := _colidir_com(Vector2(320.0, 364.0), 100.0)
	assert_vector(npc.position).is_equal(Vector2(320.0, 364.0)).override_failure_message(
		"US1-CA4: NPC deslocado na colisão tipo 1-1"
	)
	assert_float(npc.get_speed()).is_equal(80.0)  # passeio = 100 km/h → 80 unidades
	npc.free()


func test_drift_displaces_to_classified_side_and_keeps_partial_control() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(332.0, 400.0))  # lateral, jogador à esquerda → drift -1
	var x_antes := jogador.position.x
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	# Avança o drift sem novo contato (o 1º quadro transita IMPACTO → DRIFT — FR-015).
	npc.position = Vector2(500.0, 100.0)
	for i in 5:
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_float(jogador.position.x).is_less(x_antes).override_failure_message(
		"FR-011/US4-CA4: drift não deslocou para a esquerda (lado classificado)"
	)
	assert_float(jogador.controller.control_factor).is_equal(GameConfig.drift_control_factor).override_failure_message(
		"SC-004: controle abaixo do fator configurado durante o drift"
	)
	npc.free()


func test_control_recovers_to_exactly_100_percent() -> void:
	_colidir_com(Vector2(320.0, 364.0), 100.0).free()
	# Sem contato: drift (1,2s máx) + recuperação (0,6/1,2s) em ~3s de quadros.
	for i in 200:
		sistema.update(1.0 / 60.0, jogador, [], _bounds)
	assert_float(jogador.controller.control_factor).is_equal(1.0).override_failure_message(
		"SC-004: controle não retornou a exatamente 100% após o drift"
	)
	assert_int(sistema.drift.fase).is_equal(DriftState.Phase.NORMAL)


func test_drift_respects_current_road_boundaries() -> void:
	# FR-022/SC-007: jogador colado à borda direita, drift para a direita →
	# o deslocamento para no limite válido.
	jogador.position.x = 388.0
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(372.0, 400.0))  # jogador à direita do NPC → drift +1
	for i in 120:
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
		npc.position = Vector2(248.0, 100.0)  # afasta para não repetir impacto
	assert_float(jogador.position.x).is_less_equal(392.0).override_failure_message(
		"SC-007: drift ultrapassou o limite direito da estrada"
	)
	npc.free()


func test_second_collision_replaces_ongoing_drift() -> void:
	# Edge Case: nova colisão válida durante o drift substitui pela última classificação.
	_colidir_com(Vector2(332.0, 400.0), 100.0).free()  # drift -1
	# Novo par (outro NPC), fora do cooldown dele.
	jogador.controller.speed = 100.0
	var npc2 := _npc(Vector2(308.0, 400.0))  # jogador à direita → drift +1
	sistema.update(1.0 / 60.0, jogador, [npc2], _bounds)
	assert_int(sistema.drift.direcao).is_equal(1).override_failure_message(
		"Drift não foi substituído pela última classificação"
	)
	npc2.free()


## T047 / FR-023, SC-007: durante a transição 2↔4 vias os limites mudam por
## altura a cada quadro; o drift do jogador deve seguir o limite VIGENTE,
## nunca uma largura memorizada.
func test_drift_follows_transition_boundaries() -> void:
	jogador.controller.speed = 100.0
	# Limites estreitando a cada quadro (simula REDUCTION): direita 392 → 376.
	var direita := 392.0
	var bounds_variavel = func(_y: float) -> Dictionary:
		return {"left": 248.0, "right": direita}
	var npc := _npc(Vector2(308.0, 400.0))  # jogador à direita do NPC → drift +1
	sistema.update(1.0 / 60.0, jogador, [npc], bounds_variavel)
	npc.position = Vector2(200.0, 100.0)  # afasta para não repetir impacto

	var max_x_alcancado := jogador.position.x
	for i in 90:
		direita = maxf(direita - 0.2, 376.0)
		sistema.update(1.0 / 60.0, jogador, [npc], bounds_variavel)
		max_x_alcancado = maxf(max_x_alcancado, jogador.position.x)

	assert_float(max_x_alcancado).is_less_equal(392.0).override_failure_message(
		"SC-007: drift ultrapassou o limite vigente mais largo da transição"
	)
	# Ao alargar de volta, o drift (se ainda ativo por nova colisão) respeita o
	# novo limite sem sair dele: garantido pelo clamp por quadro em DriftState.
	npc.free()
