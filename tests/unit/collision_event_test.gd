extends GdUnitTestSuite

## SPEC-005 / T037 — evento de colisão: um por colisão válida, com os 6 dados
## mínimos do contrato (FR-029, SC-008), tipos distinguíveis (US6-CA2) e zero
## emissões sob cooldown (FR-028, US6-CA3).

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


func test_event_payload_has_minimum_fields() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(332.0, 400.0))  # lateral, jogador à esquerda
	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_int(eventos.size()).is_equal(1)
	var e: CollisionData = eventos[0]
	assert_object(e.player).is_same(jogador)
	assert_object(e.npc).is_same(npc)
	assert_int(e.tipo).is_equal(CollisionData.CollisionType.LATERAL)
	assert_float(e.velocidade_impacto).is_greater_equal(0.0)
	assert_float(e.intensidade).is_between(0.0, 1.0)
	assert_int(e.direcao_drift).is_not_equal(0)
	npc.free()


func test_event_distinguishes_all_three_types() -> void:
	var tipos: Array = []
	sistema.collision_occurred.connect(func(d): tipos.append(d.tipo))

	var posicoes := [
		Vector2(320.0, 364.0),  # 1-1: jogador atrás, mais rápido
		Vector2(340.0, 400.0),  # 1-2: lateral
		Vector2(320.0, 436.0),  # 1-3: jogador à frente, mais lento
	]
	for pos in posicoes:
		sistema = CollisionSystem.new()
		sistema.collision_occurred.connect(func(d): tipos.append(d.tipo))
		jogador.controller.speed = 100.0 if pos.y < 400.0 else 30.0
		if pos.x != 320.0:
			jogador.controller.speed = 100.0
		var npc := _npc(pos)
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
		npc.free()

	assert_array(tipos).contains_exactly([
		CollisionData.CollisionType.PLAYER_HITS_NPC_REAR,
		CollisionData.CollisionType.LATERAL,
		CollisionData.CollisionType.NPC_HITS_PLAYER_REAR,
	])


func test_no_event_under_cooldown() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(320.0, 364.0))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	# Ainda sobrepostos no quadro seguinte → mesmo impacto: zero eventos novos.
	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_int(eventos.size()).is_zero().override_failure_message(
		"FR-028/SC-008: colisão sob cooldown emitiu evento"
	)
	npc.free()
