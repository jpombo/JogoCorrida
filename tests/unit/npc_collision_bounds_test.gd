extends GdUnitTestSuite

## SPEC-006 / T023 — invariante de pista (SC-006, SC-007, SC-018, FR-018–FR-022):
## inversão da direção na borda, transferência do deslocamento ao causador
## quando nenhum lado comporta, zero veículos fora da área trafegável por
## quadro e limites consultados por altura durante a transição 2↔4 vias.

const BOUNDS_PADRAO := {"left": 248.0, "right": 392.0}
const BOUNDS_ESTREITOS := {"left": 300.0, "right": 344.0}

var sistema: NpcCollisionSystem
var eventos: Array = []

## Largura corrente da transição 2↔4 vias — MEMBRO porque a bounds callable
## precisa ler o valor ao vivo (lambda captura locais por valor no GDScript).
var _direita_transicao: float = 392.0


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	eventos.clear()
	_direita_transicao = 392.0
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


func _bounds_padrao(_y: float) -> Dictionary:
	return BOUNDS_PADRAO


func _bounds_transicao(_y: float) -> Dictionary:
	return {"left": 248.0, "right": _direita_transicao}


## FR-019 / R3 — atingido colado na borda direita com direção normal "direita":
## o drift inverte para a esquerda (o único caminho que mantém o invariante
## "ninguém sai da pista", SC-006) e o causador não recebe nada (FR-016).
func test_border_inverts_drift_to_opposite_side() -> void:
	var caminhao := _npc("caminhao", Vector2(372.0, 200.0))
	var esporte := _npc("esporte", Vector2(360.0, 250.0))
	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds_padrao)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: contato na borda não gerou 1 evento"
	)
	assert_int(eventos[0].direcao_drift).is_equal(-1).override_failure_message(
		"FR-019: direção normal não inverteu para o lado oposto na borda"
	)
	assert_int(caminhao.npc_drift.direcao).is_equal(-1).override_failure_message(
		"FR-019: drift do atingido não recebeu a direção invertida"
	)

	var x_ini: float = caminhao.position.x
	for i in 60:
		sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds_padrao)
		# SC-006: em NENHUM quadro o veículo sai da área trafegável
		# (limites com meia-largura descontada, consultados por altura).
		assert_float(caminhao.position.x).is_greater_equal(263.0).override_failure_message(
			"SC-006: quadro %d — atingido ultrapassou a borda esquerda" % i
		)
		assert_float(caminhao.position.x).is_less_equal(377.0).override_failure_message(
			"SC-006: quadro %d — atingido ultrapassou a borda direita" % i
		)
	assert_float(caminhao.position.x).is_less(x_ini).override_failure_message(
		"SC-005: drift invertido não deslocou o atingido para a esquerda"
	)
	assert_bool(esporte.npc_drift.ativo()).is_false().override_failure_message(
		"FR-016: causador recebeu drift na inversão de borda"
	)
	caminhao.free()
	esporte.free()


## FR-019 / R3 — corredor estreito sem espaço em NENHUM lado: o deslocamento
## é transferido ao causador (direção invertida), também clampado pelos
## limites dele; o atingido permanece onde está.
func test_no_space_transfers_drift_to_causador() -> void:
	var caminhao := _npc("caminhao", Vector2(322.0, 200.0))
	var esporte := _npc("esporte", Vector2(314.0, 250.0))
	var bounds_estreitos: Callable = func(_y: float) -> Dictionary: return BOUNDS_ESTREITOS
	sistema.update(1.0 / 60.0, [caminhao, esporte], bounds_estreitos)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: contato no corredor estreito não gerou 1 evento"
	)
	assert_int(eventos[0].direcao_drift).is_equal(-1).override_failure_message(
		"FR-019: direção efetiva da transferência incorreta"
	)
	assert_bool(caminhao.npc_drift.ativo()).is_false().override_failure_message(
		"FR-019: atingido sem espaço ainda recebeu o drift"
	)
	assert_bool(esporte.npc_drift.ativo()).is_true().override_failure_message(
		"FR-019: deslocamento não foi transferido ao causador"
	)
	assert_int(esporte.npc_drift.direcao).is_equal(-1).override_failure_message(
		"FR-019: transferência não inverteu a direção"
	)
	assert_bool(eventos[0].causador == esporte).is_true().override_failure_message(
		"R9: classificação de causador alterada pelo fallback"
	)
	assert_bool(eventos[0].atingido == caminhao).is_true().override_failure_message(
		"R9: classificação de atingido alterada pelo fallback"
	)

	for i in 60:
		sistema.update(1.0 / 60.0, [caminhao, esporte], bounds_estreitos)
		# SC-006: ambos dentro da área trafegável do corredor estreito.
		assert_float(caminhao.position.x).is_greater_equal(315.0).override_failure_message(
			"SC-006: quadro %d — atingido saiu pela esquerda do corredor" % i
		)
		assert_float(caminhao.position.x).is_less_equal(329.0).override_failure_message(
			"SC-006: quadro %d — atingido saiu pela direita do corredor" % i
		)
		assert_float(esporte.position.x).is_greater_equal(313.0).override_failure_message(
			"SC-006: quadro %d — causador saiu pela esquerda do corredor" % i
		)
		assert_float(esporte.position.x).is_less_equal(331.0).override_failure_message(
			"SC-006: quadro %d — causador saiu pela direita do corredor" % i
		)
	assert_float(esporte.position.x).is_less(314.0).override_failure_message(
		"FR-019: causador transferido não deslocou para a esquerda"
	)
	assert_float(caminhao.position.x).is_equal_approx(322.0, 0.001).override_failure_message(
		"FR-019: atingido sem drift se moveu"
	)
	caminhao.free()
	esporte.free()


## SC-018 / T026 — o limite de deslocamento acumulado vale mesmo com força
## absurda: `npc_displacement_limit` é teto independente da intensidade.
func test_displacement_never_exceeds_configured_limit() -> void:
	var estado := NpcDriftState.new()
	estado.iniciar(1, 500.0, 10.0)
	var x: float = 0.0
	var total: float = 0.0
	for i in 600:
		var deslocamento: float = estado.proximo_deslocamento(
			1.0 / 60.0, x, -100000.0, 100000.0
		)
		x += deslocamento
		total += absf(deslocamento)

	assert_float(total).is_less_equal(
		GameConfig.npc_displacement_limit + 0.001
	).override_failure_message(
		"FR-020: deslocamento acumulado (%.1f) excedeu o limite" % total
	)
	assert_float(x).is_greater_equal(0.0).override_failure_message(
		"FR-015: drift com limites abertos deslocou para o lado errado"
	)


## FR-018 / FR-040 / T024 — transição 2↔4 vias: os limites são consultados
## na ALTURA do veículo a cada quadro (nunca largura memorizada) e o clamp
## vigente vale durante DRIFT **e** RECUPERACAO (FR-022): o veículo é
## puxado de volta para dentro conforme o corredor encolhe, e zero quadros
## com posição fora dos limites vigentes.
func test_transition_bounds_respected_every_frame() -> void:
	var caminhao := _npc("caminhao", Vector2(340.0, 200.0))
	var esporte := _npc("esporte", Vector2(313.0, 240.0))
	var encolhendo: bool = true

	for i in 110:
		if encolhendo:
			_direita_transicao = maxf(_direita_transicao - 0.4, 364.0)
			if _direita_transicao <= 364.0:
				encolhendo = false
		else:
			_direita_transicao = minf(_direita_transicao + 0.7, 392.0)
		sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds_transicao)

		# SC-006/SC-007: limite vigente NESTE quadro na altura do veículo.
		var limite_caminhao: float = _direita_transicao - 15.0
		assert_float(caminhao.position.x).is_less_equal(
			limite_caminhao + 0.001
		).override_failure_message(
			"SC-007: quadro %d — atingido além do limite vigente (%.1f > %.1f)"
			% [i, caminhao.position.x, limite_caminhao]
		)
		assert_float(caminhao.position.x).is_greater_equal(263.0).override_failure_message(
			"SC-006: quadro %d — atingido ultrapassou a borda esquerda" % i
		)
		var limite_esporte: float = _direita_transicao - 13.0
		assert_float(esporte.position.x).is_less_equal(
			limite_esporte + 0.001
		).override_failure_message(
			"SC-007: quadro %d — causador além do limite vigente" % i
		)
		assert_float(esporte.position.x).is_greater_equal(261.0).override_failure_message(
			"SC-006: quadro %d — causador ultrapassou a borda esquerda" % i
		)

	assert_int(eventos.size()).is_equal(1).override_failure_message(
		"SC-004: transição gerou mais de um evento para o mesmo contato"
	)
	assert_bool(caminhao.npc_drift.ativo() or eventos.size() == 1).is_true().override_failure_message(
		"sanidade: contato da transição não ocorreu"
	)
	caminhao.free()
	esporte.free()
