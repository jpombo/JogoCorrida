extends GdUnitTestSuite

## SPEC-006 / T038 — contrato do evento (FR-041, contracts/npc_collision_event.md):
## - exatamente 1 evento por colisão válida, no quadro do contato, com os 7
##   campos preenchidos e coerentes;
## - 0 eventos sob cooldown do par (FR-027) e sob bloqueio de cadeia
##   (FR-025/FR-027);
## - sem ouvintes o sistema continua se comportando igual — o sinal é
##   puramente observacional, nenhum consumidor é obrigatório (US6-CA5).

const BOUNDS := {"left": 248.0, "right": 392.0}

var sistema: NpcCollisionSystem
var eventos: Array = []


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	eventos.clear()
	sistema.npc_collision_occurred.connect(func(d): eventos.append(d))


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


## US6-CA1 / FR-041 — exatamente 1 evento com os 7 campos do contrato,
## emitido no quadro do contato (A atinge B na traseira): causador A,
## atingido B, tipo LONGITUDINAL, intensidade normalizada, direção efetiva
## ≠ 0, cadeia raiz própria e profundidade 1.
func test_one_event_with_all_seven_fields() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	_atualizar([a, b], 2)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-041: %d eventos no primeiro contato (esperado 1)" % eventos.size()
	)
	var d: NpcCollisionData = eventos[0]
	assert_bool(d.causador == a).is_true().override_failure_message(
		"FR-041: campo causador incorreto"
	)
	assert_bool(d.atingido == b).is_true().override_failure_message(
		"FR-041: campo atingido incorreto"
	)
	assert_bool(
		d.tipo == NpcCollisionData.Tipo.LONGITUDINAL
		or d.tipo == NpcCollisionData.Tipo.LATERAL
	).is_true().override_failure_message("FR-011: tipo fora do enum")
	assert_float(d.intensidade).is_between(0.0, 1.0).override_failure_message(
		"FR-012: intensidade fora de [0,1]: %f" % d.intensidade
	)
	assert_bool(d.direcao_drift == -1 or d.direcao_drift == 1).is_true(
	).override_failure_message("FR-015: direção efetiva 0 ou inválida")
	assert_int(d.cadeia_id).is_greater(0).override_failure_message(
		"FR-024: impacto raiz sem cadeia própria"
	)
	assert_int(d.profundidade).is_equal(1).override_failure_message(
		"FR-025: impacto raiz com profundidade ≠ 1"
	)

	# Sobreposição persistente no quadro seguinte: mesmo impacto, 1 evento só.
	_atualizar([a, b], 3)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-041: contato contínuo emitiu de novo (%d)" % eventos.size()
	)
	a.free()
	b.free()


## US6-CA2 / FR-027 — cooldown do par: contato processado, separação e
## reencostada dentro da janela → 0 eventos novos (o cooldown protege o
## episódio, não o veículo).
func test_zero_events_while_pair_cooldown_active() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	_atualizar([a, b], 1)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto raiz não ocorreu"
	)

	# Separa (latch some; cooldown segue correndo) e reencosta 2 quadros
	# depois — bem dentro de npc_collision_cooldown (0,8 s).
	b.position.x = 100.0
	_atualizar([a, b], 1)
	b.position.x = 356.0
	_atualizar([a, b], 2)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-027: reencostada em cooldown emitiu evento (%d)" % eventos.size()
	)
	a.free()
	b.free()


## US6-CA3 / FR-025 — bloqueio de cadeia: quinto NPC além de
## npc_max_chain_depth não gera evento algum (a cadeia registra, o sistema
## não emite para o elo barrado).
func test_zero_events_when_chain_depth_blocks() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var c := _npc("caminhao", Vector2(328.0, 240.0))
	var d := _npc("esporte", Vector2(299.0, 240.0))
	var e := _npc("passeio", Vector2(272.0, 240.0))

	# Mesma fileira da CA2 da suíte de cadeia: 3 elos processados e o quarto
	# (D→E) bloqueado pelo teto de profundidade.
	_atualizar([a, b, c, d, e], 90)

	assert_int(eventos.size()).is_equal(
		3
	).override_failure_message(
		"FR-025: elo bloqueado emitiu evento (%d, esperado 3)" % eventos.size()
	)
	var ultimo_prof: int = 0
	for evento in eventos:
		ultimo_prof = maxi(ultimo_prof, evento.profundidade)
	assert_int(ultimo_prof).is_equal(
		GameConfig.npc_max_chain_depth
	).override_failure_message("FR-025: cadeia não parou no teto configurado")
	a.free()
	b.free()
	c.free()
	d.free()
	e.free()


## US6-CA5 / FR-041 — sem ouvintes nada muda: o sistema roda igual, aplica
## a consequência (drift) e não reclama — nenhum consumidor é obrigatório.
func test_system_behaves_identically_without_listeners() -> void:
	var mudo: NpcCollisionSystem = NpcCollisionSystem.new()
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))

	for i in range(30):
		mudo.update(1.0 / 60.0, [a, b], _bounds)

	assert_bool(b.position.x < 356.0).is_true().override_failure_message(
		"FR-041: sem ouvintes a consequência do impacto não foi aplicada"
	)
	a.free()
	b.free()
