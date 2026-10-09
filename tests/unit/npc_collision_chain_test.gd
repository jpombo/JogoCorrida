extends GdUnitTestSuite

## SPEC-006 / T027 — cadeia de colisão (SC-008, FR-024/FR-025, research R4):
## A→B→C com profundidade progressiva, teto de profundidade bloqueando o
## quarto elo, veículo já processado descartado (0 loops), expiração por
## tempo e cadeias paralelas com ids/prófundidades próprios (Q5). O elo de
## encadeamento é o deslocamento do atingido: causador com drift ativo
## herdando a cadeia dele.
##
## Geometria comum — fileira marchando para a ESQUERDA (pista 248…392):
## A atinge B por trás; B desloca à esquerda e toca C; C toca D; D toca E.

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


## US5-CA1 / SC-008 — três NPCs em fila: A→B cria a cadeia (profundidade 1)
## e o deslocamento de B (drift ativo, portador do elo) atinge C, herdando a
## MESMA cadeia com profundidade 2.
func test_chain_a_to_b_to_c_depth_two() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var c := _npc("caminhao", Vector2(328.0, 240.0))

	_atualizar([a, b, c], 40)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"SC-008: cadeia A→B→C gerou %d eventos (esperado 2)" % eventos.size()
	)
	assert_int(eventos[0].profundidade).is_equal(1).override_failure_message(
		"FR-025: impacto raiz não registrou profundidade 1"
	)
	assert_int(eventos[1].profundidade).is_equal(2).override_failure_message(
		"SC-008: segundo elo não registrou profundidade 2"
	)
	assert_int(eventos[1].cadeia_id).is_equal(eventos[0].cadeia_id).override_failure_message(
		"FR-024: elo não herdou a cadeia do impacto raiz"
	)
	assert_bool(b.npc_drift.ativo() or c.npc_drift.ativo()).is_true().override_failure_message(
		"sanidade: deslocamento do atingido não ocorreu"
	)
	a.free()
	b.free()
	c.free()


## US5-CA2 / FR-025 — cinco NPCs em fila: os elos 1, 2 e 3 processam nas
## profundidades 1, 2 e 3 (= npc_max_chain_depth); o quarto elo (D→E) seria
## profundidade 4 → bloqueado: sem evento e sem consequência para E.
func test_chain_stops_at_maximum_depth() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var c := _npc("caminhao", Vector2(328.0, 240.0))
	var d := _npc("esporte", Vector2(299.0, 240.0))
	var e := _npc("passeio", Vector2(272.0, 240.0))

	# 90 quadros = 1,5 s < npc_chain_timeout (2 s): a cadeia segue viva e o
	# bloqueio de profundidade é o que impede o quarto elo.
	_atualizar([a, b, c, d, e], 90)

	assert_int(eventos.size()).is_equal(3).override_failure_message(
		"FR-025: quarto elo não foi bloqueado (%d eventos, esperado 3)" % eventos.size()
	)
	for i in range(eventos.size()):
		assert_int(eventos[i].profundidade).is_equal(i + 1).override_failure_message(
			"FR-025: evento %d com profundidade %d (esperado %d)"
			% [i, eventos[i].profundidade, i + 1]
		)
	assert_int(eventos[2].profundidade).is_equal(
		GameConfig.npc_max_chain_depth
	).override_failure_message("FR-025: cadeia não alcançou a profundidade máxima")
	assert_bool(e.npc_drift.ativo()).is_false().override_failure_message(
		"FR-027: quarto elo bloqueado aplicou consequência em E"
	)
	# Posição é o vestígio permanente: D deslocou (3º elo válido) e E nunca
	# sofreu drift (4º elo bloqueado) — o drift em si já terminou no frame 90.
	assert_float(e.position.x).is_equal_approx(272.0, 0.001).override_failure_message(
		"FR-027: E se moveu apesar do bloqueio de profundidade"
	)
	assert_float(d.position.x).is_less(299.0).override_failure_message(
		"sanidade: terceiro elo (D atingido) não deslocou"
	)
	a.free()
	b.free()
	c.free()
	d.free()
	e.free()


## US5-CA4 / FR-025 — veículo já processado na cadeia: C (portador do drift
## da cadeia, sellado com o id do evento raiz) atinge B de novo → B ∈
## processados → impacto descartado: 0 eventos e drift de B não reinicia.
func test_processed_vehicle_is_not_processed_twice() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	_atualizar([a, b], 1)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto raiz não ocorreu"
	)
	var id_cadeia: int = eventos[0].cadeia_id

	# A sai de cena; B segue com o drift da cadeia.
	a.state = TrafficVehicle.State.INACTIVE
	_atualizar([a, b], 5)
	var tempo_antes: float = b.npc_drift.tempo_decorrido

	# C carrega o drift da cadeia raiz e atinge B (o já processado).
	var c := _npc("esporte", Vector2(b.position.x, 278.0))
	c.aplicar_drift_npc(1, 60.0, 0.6, id_cadeia, 1)
	_atualizar([a, b, c], 10)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"FR-025: veículo já processado gerou novo evento (%d > 1)" % eventos.size()
	)
	assert_float(b.npc_drift.tempo_decorrido).is_greater(tempo_antes).override_failure_message(
		"FR-027: impacto descartado reiniciou o drift do atingido"
	)
	a.free()
	b.free()
	c.free()


## US5-CA5 / FR-025 — expiração por tempo: com a cadeia raiz vencida
## (npc_chain_timeout), o drift de C sellado com o id antigo NÃO encontra a
## cadeia → sem elo → impacto vira raiz de cadeia PRÓPRIA (id novo,
## profundidade 1): nenhum elo adicional da cadeia expirada.
func test_expired_chain_yields_no_further_links() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	_atualizar([a, b], 1)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto raiz não ocorreu"
	)
	var id_cadeia: int = eventos[0].cadeia_id

	a.state = TrafficVehicle.State.INACTIVE
	# 140 quadros = 2,33 s > npc_chain_timeout (2,0 s): a cadeia expira.
	_atualizar([a, b], 140)

	var c := _npc("esporte", Vector2(b.position.x, 278.0))
	c.aplicar_drift_npc(1, 60.0, 0.6, id_cadeia, 1)
	_atualizar([a, b, c], 5)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"FR-025: impacto pós-expiração não ocorreu (%d eventos)" % eventos.size()
	)
	assert_int(eventos[1].cadeia_id).is_not_equal(id_cadeia).override_failure_message(
		"FR-025: impacto herdou cadeia expirada"
	)
	assert_int(eventos[1].profundidade).is_equal(1).override_failure_message(
		"FR-025: cadeia expirada não recomeçou como raiz (profundidade 1)"
	)
	a.free()
	b.free()
	c.free()


## US5-CA7 / FR-014 + Q4 — NPC em drift atingido por um terceiro DE OUTRO
## PAR (sem elo): cadeia própria nova e o drift atual é SUBSTITuíDO
## (direção/força/duração reiniciadas, id trocado).
func test_new_impact_substitutes_active_drift() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	_atualizar([a, b], 6)
	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"sanidade: impacto raiz não ocorreu"
	)
	var id_cadeia_raiz: int = eventos[0].cadeia_id
	a.state = TrafficVehicle.State.INACTIVE
	assert_bool(b.npc_drift.ativo()).is_true().override_failure_message(
		"sanidade: B sem drift antes da substituição"
	)

	var c := _npc("esporte", Vector2(b.position.x, 278.0))
	_atualizar([a, b, c], 1)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"Q4: impacto de outro par não gerou evento"
	)
	assert_int(eventos[1].cadeia_id).is_not_equal(id_cadeia_raiz).override_failure_message(
		"Q5: impacto sem elo herdou cadeia alheia por proximidade"
	)
	assert_int(eventos[1].profundidade).is_equal(1).override_failure_message(
		"Q5: impacto sem elo não iniciou cadeia própria (profundidade 1)"
	)
	assert_int(b.npc_drift.cadeia_id).is_equal(eventos[1].cadeia_id).override_failure_message(
		"FR-014: drift substituído não recebeu a cadeia do novo impacto"
	)
	assert_float(b.npc_drift.tempo_decorrido).is_less(1.0 / 30.0).override_failure_message(
		"FR-014: drift não foi reiniciado (tempo_decorrido não zerou)"
	)
	a.free()
	b.free()
	c.free()


## US5-CA8 / Q5 — duas colisões independentes dentro do tempo de expiração
## de uma cadeia ativa: cada uma recebe id e profundidade PRÓPRIOS; nenhuma
## herda a cadeia alheia só por acontecer perto no tempo.
func test_parallel_chains_have_own_ids() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var d := _npc("esporte", Vector2(276.0, 278.0))
	var e := _npc("passeio", Vector2(274.0, 240.0))

	_atualizar([a, b, d, e], 10)

	assert_int(eventos.size()).is_equal(2).override_failure_message(
		"Q5: pares independentes geraram %d eventos (esperado 2)" % eventos.size()
	)
	assert_int(eventos[0].cadeia_id).is_not_equal(eventos[1].cadeia_id).override_failure_message(
		"Q5: colisão paralela herdou cadeia alheia por proximidade no tempo"
	)
	assert_int(eventos[0].profundidade).is_equal(1).override_failure_message(
		"Q5: primeira colisão paralela não é raiz (profundidade 1)"
	)
	assert_int(eventos[1].profundidade).is_equal(1).override_failure_message(
		"Q5: segunda colisão paralela não é raiz (profundidade 1)"
	)
	a.free()
	b.free()
	d.free()
	e.free()
