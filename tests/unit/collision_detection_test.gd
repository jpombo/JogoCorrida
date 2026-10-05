extends GdUnitTestSuite

## SPEC-005 / T012 — detecção: interseção de hitbox ↔ exatamente uma colisão
## válida no quadro; sem interseção, nenhuma; NPC×NPC e decoração não colidem
## (FR-001, FR-031, SC-001).

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


func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = Vector2(32.0, 48.0)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


func test_intersecting_hitboxes_generate_exactly_one_collision() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc("passeio", Vector2(320.0, 364.0))  # traseira: dy=36 < soma das meias-alturas

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_int(eventos.size()).is_equal(1).override_failure_message("SC-001: uma interseção, uma colisão")
	# No quadro seguinte ainda sobrepostos: mesmo impacto, sem nova colisão.
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	assert_int(eventos.size()).is_equal(1).override_failure_message("SC-001: sobreposição persistente não redesdetecta")
	npc.free()


func test_no_intersection_no_collision() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc("passeio", Vector2(320.0, 100.0))  # longe à frente

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_int(eventos.size()).is_zero().override_failure_message("SC-001: colisão sem interseção de hitboxes")


func test_npc_vs_npc_overlap_does_not_collide() -> void:
	# FR-031: colisão NPC×NPC não existe — mesmo com dois NPCs sobrepostos entre
	# si, nenhum evento é emitido enquanto nenhum tocar o jogador.
	jogador.controller.speed = 100.0
	var npc_a := _npc("passeio", Vector2(300.0, 100.0))
	var npc_b := _npc("utilitario", Vector2(302.0, 102.0))  # sobrepostos entre si, longe do jogador

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc_a, npc_b], _bounds)

	assert_int(eventos.size()).is_zero().override_failure_message("FR-031: NPC×NPC gerou colisão")
	npc_a.free()
	npc_b.free()


func test_inactive_npc_is_ignored() -> void:
	jogador.controller.speed = 100.0
	var npc := _npc("passeio", Vector2(320.0, 364.0))
	npc.state = TrafficVehicle.State.INACTIVE

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_int(eventos.size()).is_zero().override_failure_message("NPC inativo (pool) participou da detecção")
	npc.free()
