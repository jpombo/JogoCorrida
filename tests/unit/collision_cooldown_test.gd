extends GdUnitTestSuite

## SPEC-005 / T033 — cooldown por par jogador↔NPC (FR-026/FR-027), zero
## consequência sob cooldown (FR-028), rearma apenas após separação e novo
## contato (US5-CA3, SC-005).

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


func test_sustained_overlap_penalizes_once() -> void:
	# SC-005: veículos mantidos sobrepostos → uma única penalização em todo o cooldown.
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(320.0, 364.0))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	var apos_primeira := jogador.controller.speed
	for i in 120:  # 2s sobrepostos — bem além do cooldown
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_float(jogador.controller.speed).is_equal(apos_primeira).override_failure_message(
		"SC-005: penalização repetida durante sobreposição persistente"
	)
	npc.free()


func test_different_npc_collides_during_cooldown() -> void:
	# US5-CA2: cooldown é por par — outro NPC colide normalmente (FR-027, Edge Case).
	jogador.controller.speed = 100.0
	var npc_a := _npc(Vector2(320.0, 364.0))
	sistema.update(1.0 / 60.0, jogador, [npc_a], _bounds)
	npc_a.position = Vector2(200.0, 100.0)  # afasta sem desativar

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	var npc_b := _npc(Vector2(308.0, 400.0), "utilitario")  # lateral com outro NPC
	sistema.update(1.0 / 60.0, jogador, [npc_a, npc_b], _bounds)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-027: NPC diferente bloqueado pelo cooldown de outro par"
	)
	npc_a.free()
	npc_b.free()


func test_new_collision_only_after_separation_and_new_contact() -> void:
	# US5-CA3: cooldown zerado com sobreposição persistente → nada; só após
	# separar e voltar a tocar (e com cooldown zerado) há nova colisão.
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(320.0, 364.0))
	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_int(eventos.size()).is_equal(1)

	# 2s sobrepostos: cooldown expira, mas não há separação → nenhum evento novo.
	for i in 120:
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"US5-CA3: novo evento sem separação prévia"
	)

	# Separação imediata + recontato DENTRO do cooldown seguinte? Cooldown já
	# expirou acima; recontato rápido ainda no mesmo quadro de separação + novo
	# contato: separa por 5 quadros (cooldown inativo) e aproxima de novo.
	npc.position = Vector2(200.0, 100.0)
	for i in 5:
		sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	# O primeiro impacto deslocou o jogador pelo drift; realinha à geometria
	# original — o alvo deste teste é o cooldown por par, não a deriva lateral.
	jogador.position = Vector2(320.0, 400.0)
	npc.position = Vector2(320.0, 364.0)
	jogador.controller.speed = 100.0
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"US5-CA3: separação + novo contato não gerou nova colisão"
	)
	npc.free()


func test_collision_during_cooldown_emits_nothing() -> void:
	# FR-028: re-contato dentro do cooldown (após separação) não emite evento.
	jogador.controller.speed = 100.0
	var npc := _npc(Vector2(320.0, 364.0))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	npc.position = Vector2(200.0, 100.0)
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)  # separou (rearma o par)
	npc.position = Vector2(320.0, 364.0)
	jogador.controller.speed = 100.0

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)  # recontato DENTRO do cooldown
	assert_int(eventos.size()).is_zero().override_failure_message(
		"FR-028: colisão sob cooldown emitiu evento"
	)
	npc.free()
