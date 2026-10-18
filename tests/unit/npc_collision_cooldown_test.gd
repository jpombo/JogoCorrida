extends GdUnitTestSuite

## SPEC-006 / T028 — cooldown por PAR (SC-009, FR-026/FR-027, research R5):
## A↔B em cooldown não emite evento nem consequência enquanto B↔C (par
## distinto) colide normalmente; rearmento exige expiração E separação; par
## que separa e reencosta durante o cooldown continua bloqueado.
##
## A separação é feita MOVENDO o veículo (nunca desativando): um par com
## membro inativo é pulado antes do teste de sobreposição e o latch do
## episódio sobreviveria — o teste teria de passar pelo motivo errado.

const BOUNDS := {"left": 248.0, "right": 392.0}

var sistema: NpcCollisionSystem
var eventos: Array = []


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	eventos.clear()
	sistema.npc_collision_occurred.connect(
		func(data: NpcCollisionData) -> void: eventos.append(data)
	)


func after_test() -> void:
	sistema = null
	eventos.clear()


func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = GameConfig.NPC_HITBOX_SIZES[categoria_id]
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS


func _atualizar(npcs: Array, quadros: int) -> void:
	for i in quadros:
		sistema.update(1.0 / 60.0, npcs, _bounds)


## US5-CA3 / SC-009 — isolamento por par: A↔B recém-impactado (cooldown de
## npc_collision_cooldown) segue bloqueado — inclusive num novo toque —
## enquanto B↔C colide e emite evento normalmente.
func test_pair_cooldown_does_not_block_other_pair() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))

	_atualizar([a, b], 1)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto A↔B não ocorreu"
	)

	# A se afasta: separação desarma o latch; o cooldown do par segue tiquetaque.
	a.position = Vector2(358.0, 420.0)
	_atualizar([a, b], 2)

	# C toca B: outro par, sem cooldown — evento normal.
	var c := _npc("esporte", Vector2(b.position.x, 278.0))
	_atualizar([a, b, c], 2)
	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"SC-009: par B↔C não colidiu durante o cooldown de A↔B (%d eventos)"
		% eventos.size()
	)
	assert_bool(
		eventos[1].causador == c or eventos[1].atingido == c
	).is_true().override_failure_message("SC-009: segundo evento não é do par B↔C")

	# C se afasta; A reencosta em B ainda DENTRO do cooldown → bloqueado
	# sem evento nem consequência (FR-027).
	c.position = Vector2(356.0, 460.0)
	a.position = Vector2(b.position.x, 278.0)
	_atualizar([a, b, c], 6)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"FR-026: recontato durante o cooldown emitiu evento (%d > 2)" % eventos.size()
	)
	a.free()
	b.free()
	c.free()


## US5-CA6 / FR-026 — rearmento exige expiração E separação: reencostar
## durante o cooldown → 0 eventos; separar, esperar a expiração e reencostar
## → nova colisão.
func test_pair_rearms_only_after_expiry_and_separation() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))

	_atualizar([a, b], 1)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto A↔B não ocorreu"
	)

	# Reencoste cedo: A afasta, espera 10 quadros (cooldown ainda ativo) e
	# volta — nenhum evento (FR-026: separação sozinha não rearma).
	a.position = Vector2(358.0, 420.0)
	_atualizar([a, b], 10)
	a.position = Vector2(b.position.x, 278.0)
	_atualizar([a, b], 3)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-026: recontato antes da expiração emitiu evento"
	)

	# Separa de novo e espera a expiração completa do cooldown (0,8 s) —
	# só então o rearmento acontece e o novo toque gera nova colisão.
	a.position = Vector2(358.0, 420.0)
	_atualizar([a, b], 50)
	a.position = Vector2(b.position.x, 278.0)
	_atualizar([a, b], 3)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"FR-026: rearmento pós-expiração + separação não gerou nova colisão (%d eventos)"
		% eventos.size()
	)
	a.free()
	b.free()
