extends GdUnitTestSuite

## SPEC-005 / T013 + T020 — classificação nos 3 tipos (FR-002/FR-003), direção
## do drift pelo lado relativo (FR-004) e margem neutra determinística (FR-005).

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


func _colidir(pos_npc: Vector2, vel_jogador: float = 100.0) -> Array:
	jogador.controller.speed = vel_jogador
	var npc := _npc(pos_npc)
	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	npc.free()
	return eventos


func test_player_hits_npc_rear() -> void:
	var eventos := _colidir(Vector2(320.0, 364.0))  # jogador atrás (y maior), mais rápido
	assert_int(eventos.size()).is_equal(1)
	assert_int(eventos[0].tipo).is_equal(CollisionData.CollisionType.PLAYER_HITS_NPC_REAR)


func test_lateral_collision() -> void:
	var eventos := _colidir(Vector2(340.0, 400.0))  # contato pelas laterais (dx=20, dy=0)
	assert_int(eventos.size()).is_equal(1)
	assert_int(eventos[0].tipo).is_equal(CollisionData.CollisionType.LATERAL)


func test_npc_hits_player_rear() -> void:
	var eventos := _colidir(Vector2(320.0, 436.0), 50.0)  # jogador à frente (y menor), mais lento
	assert_int(eventos.size()).is_equal(1)
	assert_int(eventos[0].tipo).is_equal(CollisionData.CollisionType.NPC_HITS_PLAYER_REAR)


func test_drift_direction_matches_relative_side() -> void:
	# US1-CA2/CA3: bateu pela esquerda sai pela esquerda; pela direita, pela direita.
	var esq := _colidir(Vector2(332.0, 400.0))  # jogador à esquerda do NPC
	assert_int(esq[0].direcao_drift).is_equal(-1)
	sistema = CollisionSystem.new()
	var dir := _colidir(Vector2(308.0, 400.0))  # jogador à direita do NPC
	assert_int(dir[0].direcao_drift).is_equal(1)


func test_neutral_margin_is_deterministic_tie_goes_left() -> void:
	# FR-005: exatamente alinhados (dx=0, dentro da margem) e espaços iguais →
	# decisão estável para a esquerda, nunca alternando.
	jogador.position.x = 320.0  # centro exato da pista: espaços iguais
	for i in 3:
		sistema = CollisionSystem.new()
		var eventos := _colidir(Vector2(320.0, 400.0))
		assert_int(eventos[0].direcao_drift).is_equal(-1).override_failure_message(
			"FR-005: empate absoluto deve cair para a esquerda (iteração %d)" % i
		)


func test_neutral_margin_prefers_side_with_more_space() -> void:
	# FR-005/Assumptions: dentro da margem, drift para o lado com mais espaço.
	jogador.position.x = 262.0  # perto da borda esquerda → mais espaço à direita
	var eventos := _colidir(Vector2(262.0, 400.0))
	assert_int(eventos[0].direcao_drift).is_equal(1).override_failure_message(
		"FR-005: margem neutra deve escolher o lado com mais espaço trafegável"
	)
