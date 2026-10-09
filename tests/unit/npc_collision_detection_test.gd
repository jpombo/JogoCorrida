extends GdUnitTestSuite

## SPEC-006 / T008 — detecção de colisão NPC×NPC: interseção de hitboxes →
## exatamente um evento classificado LONGITUDINAL com drift SOMENTE no
## atingido, causador intacto (SC-004, FR-010/FR-011/FR-016); sem interseção,
## nenhum evento (FR-010); sobreposição persistente = 1 único evento por
## episódio (latch de T007, FR-026).

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}

var sistema: NpcCollisionSystem
var eventos: Array = []


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	eventos = []
	sistema.npc_collision_occurred.connect(func(d): eventos.append(d))


func after_test() -> void:
	sistema = null


func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = GameConfig.NPC_HITBOX_SIZES[categoria_id]
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


func _atualizar(npcs: Array, quadros: int = 1) -> void:
	for i in quadros:
		sistema.update(1.0 / 60.0, npcs, _bounds)


func test_longitudinal_contact_classifies_and_drifts_only_hit() -> void:
	# Esporte alcançando a traseira do caminhão na mesma trajetória (US1-CA1).
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var esporte := _npc("esporte", Vector2(320.0, 250.0))
	_atualizar([caminhao, esporte])

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: interseção não gerou exatamente 1 evento"
	)
	var d: NpcCollisionData = eventos[0]
	assert_int(d.tipo).is_equal(NpcCollisionData.Tipo.LONGITUDINAL).override_failure_message(
		"FR-011: contato traseiro não classificado como LONGITUDINAL"
	)
	assert_bool(d.causador == esporte).is_true().override_failure_message(
		"FR-013: quem alcança (y maior) não foi o causador"
	)
	assert_bool(d.atingido == caminhao).is_true().override_failure_message(
		"FR-013: quem é alcançado não foi o atingido"
	)
	assert_bool(caminhao.npc_drift.ativo()).is_true().override_failure_message(
		"FR-014: atingido sem drift após o contato"
	)
	assert_bool(esporte.npc_drift.ativo()).is_false().override_failure_message(
		"FR-016: causador recebeu drift — só o atingido desloca"
	)
	caminhao.free()
	esporte.free()


func test_no_intersection_no_collision() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var esporte := _npc("esporte", Vector2(320.0, 120.0))  # acima, sem toque
	_atualizar([caminhao, esporte])

	assert_int(eventos.size()).is_zero().override_failure_message(
		"FR-010: colisão emitida sem interseção de hitboxes"
	)
	assert_bool(caminhao.npc_drift.ativo()).is_false().override_failure_message(
		"FR-010: drift aplicado sem contato"
	)
	caminhao.free()
	esporte.free()


func test_persistent_overlap_emits_exactly_one_event() -> void:
	# Latch de T007: enquanto o par não se separa, o episódio é UM só —
	# sem reinício de drift a cada quadro (FR-026, data-model §5).
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var esporte := _npc("esporte", Vector2(320.0, 250.0))
	_atualizar([caminhao, esporte], 8)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-026: sobreposição persistente gerou %d eventos" % eventos.size()
	)
	caminhao.free()
	esporte.free()


func test_inactive_vehicles_do_not_collide() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var esporte := _npc("esporte", Vector2(320.0, 250.0))
	esporte.state = TrafficVehicle.State.INACTIVE
	_atualizar([caminhao, esporte])

	assert_int(eventos.size()).is_zero().override_failure_message(
		"Veículo inativo (pool) participou da detecção"
	)
	caminhao.free()
	esporte.free()


## US3-CA1 / T020 — dominância horizontal classifica LATERAL: os dois lado a
## lado, causador/atingido determinísticos (nenhum deslocava → empate por
## identidade, R9), drift só no atingido e para o lado oposto ao impacto
## (FR-011, FR-013, FR-015).
func test_lateral_contact_classifies_with_deterministic_causador() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var passeio := _npc("passeio", Vector2(344.0, 200.0))
	_atualizar([caminhao, passeio])

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: contato lateral não gerou exatamente 1 evento"
	)
	var d: NpcCollisionData = eventos[0]
	assert_int(d.tipo).is_equal(NpcCollisionData.Tipo.LATERAL).override_failure_message(
		"FR-011: dominância horizontal não classificou LATERAL"
	)
	var esperado_causador: TrafficVehicle = (
		passeio if passeio.get_instance_id() > caminhao.get_instance_id() else caminhao
	)
	var esperado_atingido: TrafficVehicle = (
		caminhao if esperado_causador == passeio else passeio
	)
	assert_bool(d.causador == esperado_causador).is_true().override_failure_message(
		"FR-013: empate de invasão não resolveu de forma estável (R9)"
	)
	assert_bool(d.atingido == esperado_atingido).is_true().override_failure_message(
		"FR-013: atingido incorreto no contato lateral"
	)
	assert_bool(d.atingido.npc_drift.ativo()).is_true().override_failure_message(
		"FR-014: atingido lateral sem drift"
	)
	assert_bool(d.causador.npc_drift.ativo()).is_false().override_failure_message(
		"FR-016: causador lateral recebeu drift"
	)
	var direcao_esperada: int = 1 if d.atingido.position.x > d.causador.position.x else -1
	assert_int(d.direcao_drift).is_equal(direcao_esperada).override_failure_message(
		"SC-005: drift não foi para o lado oposto ao impacto"
	)
	caminhao.free()
	passeio.free()


## US3-CA1 (outro lado) — o mesmo contato com o par espelhado: a direção
## acompanha o lado do impacto nos dois sentidos (FR-015).
func test_lateral_direction_follows_impact_side_both_ways() -> void:
	var passeio := _npc("passeio", Vector2(296.0, 200.0))
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	_atualizar([passeio, caminhao])

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: contato lateral espelhado não gerou 1 evento"
	)
	var d: NpcCollisionData = eventos[0]
	assert_int(d.tipo).is_equal(NpcCollisionData.Tipo.LATERAL).override_failure_message(
		"FR-011: par espelhado não classificou LATERAL"
	)
	var direcao_esperada: int = 1 if d.atingido.position.x > d.causador.position.x else -1
	assert_int(d.direcao_drift).is_equal(direcao_esperada).override_failure_message(
		"SC-005: direção não acompanhou o lado do impacto (espelhado)"
	)
	assert_bool(d.atingido.npc_drift.ativo()).is_true().override_failure_message(
		"FR-014: atingido espelhado sem drift"
	)
	passeio.free()
	caminhao.free()


## US3-CA2 / T020 — dentro da margem neutra (npc_relative_position_threshold)
## a decisão não vem da posição relativa: cai no lado com mais espaço e, com
## espaços iguais, sempre na mesma resposta — estável entre execuções (R2).
func test_lateral_neutral_margin_is_stable() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var passeio := _npc("passeio", Vector2(322.0, 200.0))  # dx = 2 ≤ 4 px
	_atualizar([caminhao, passeio])

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: contato lateral na margem neutra não gerou 1 evento"
	)
	var d: NpcCollisionData = eventos[0]
	assert_int(d.tipo).is_equal(NpcCollisionData.Tipo.LATERAL).override_failure_message(
		"FR-011: par na margem neutra não classificou LATERAL"
	)
	assert_int(d.direcao_drift).is_equal(-1).override_failure_message(
		"FR-015: margem neutra com espaços iguais não resolveu de forma estável"
	)
	caminhao.free()
	passeio.free()


## US3-CA3/T022 — intensidade proporcional à diferença de velocidade: mesmo
## arranjo geométrico com par de maior diferença produz `intensidade` maior,
## que é o que interpola força/duração do drift (FR-012, FR-014).
func test_lateral_intensity_scales_with_speed_difference() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var passeio := _npc("passeio", Vector2(344.0, 200.0))  # |80 − 72| = 8
	var esporte := _npc("esporte", Vector2(100.0, 400.0))   # fora do caminho
	_atualizar([caminhao, passeio, esporte])
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: primeiro contato lateral não gerou 1 evento"
	)
	var fraco: float = eventos[0].intensidade

	# Troca o par: passeio sai, esporte (|96 − 72| = 24) entra no mesmo ponto.
	passeio.position = Vector2(344.0, 60.0)
	_atualizar([caminhao, passeio, esporte])
	esporte.position = Vector2(344.0, 200.0)
	_atualizar([caminhao, passeio, esporte])

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"SC-004: segundo contato lateral não gerou 1 evento"
	)
	var forte: float = eventos[1].intensidade
	assert_float(forte).is_greater(fraco).override_failure_message(
		"FR-012: diferença de velocidade maior não elevou a intensidade (%.2f ≤ %.2f)"
		% [forte, fraco]
	)
	assert_float(forte).is_equal_approx(0.24, 0.001).override_failure_message(
		"FR-012: intensidade fora da convenção |Δv| ÷ divisor"
	)
	caminhao.free()
	passeio.free()
	esporte.free()
