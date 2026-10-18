extends GdUnitTestSuite

## SPEC-006 / T009 — drift do NPC atingido: direção oposta ao impacto pelos
## DOIS lados (FR-015, SC-005), decisão determinística dentro da margem neutra
## (research R2) e velocidade idêntica antes/durante/depois de qualquer impacto
## (FR-017, SC-014 — nenhum caminho de escrita em velocidade).

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}

var sistema: NpcCollisionSystem


func before_test() -> void:
	sistema = NpcCollisionSystem.new()


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


func _atualizar(npcs: Array, quadros: int) -> void:
	for i in quadros:
		sistema.update(1.0 / 60.0, npcs, _bounds)


func test_drift_direction_oposite_when_impact_from_left() -> void:
	# Causador atrás e à ESQUERDA do atingido → atingido desloca para a
	# direita (+1), lado oposto ao impacto (FR-015).
	var caminhao := _npc("caminhao", Vector2(324.0, 200.0))
	var esporte := _npc("esporte", Vector2(316.0, 250.0))
	var x_ini: float = caminhao.position.x
	_atualizar([caminhao, esporte], 12)

	assert_int(caminhao.npc_drift.direcao).is_equal(1).override_failure_message(
		"SC-005: impacto pela esquerda não gerou drift para a direita"
	)
	assert_float(caminhao.position.x).is_greater(x_ini).override_failure_message(
		"SC-005: atingido não desloca para a direita"
	)
	assert_bool(esporte.npc_drift.ativo()).is_false().override_failure_message(
		"FR-016: causador deslocou — só o atingido sofre drift"
	)
	assert_float(esporte.position.x).is_equal_approx(316.0, 0.001).override_failure_message(
		"FR-016: posição do causador alterada"
	)
	caminhao.free()
	esporte.free()


func test_drift_direction_oposite_when_impact_from_right() -> void:
	# Causador atrás e à DIREITA do atingido → atingido desloca para a
	# esquerda (−1) — o outro lado do par (FR-015).
	var caminhao := _npc("caminhao", Vector2(316.0, 200.0))
	var esporte := _npc("esporte", Vector2(324.0, 250.0))
	var x_ini: float = caminhao.position.x
	_atualizar([caminhao, esporte], 12)

	assert_int(caminhao.npc_drift.direcao).is_equal(-1).override_failure_message(
		"SC-005: impacto pela direita não gerou drift para a esquerda"
	)
	assert_float(caminhao.position.x).is_less(x_ini).override_failure_message(
		"SC-005: atingido não desloca para a esquerda"
	)
	caminhao.free()
	esporte.free()


func test_neutral_margin_resolves_deterministically() -> void:
	# dx = 0 (dentro da margem neutra npc_relative_position_threshold): a
	# decisão cai no lado com mais espaço; com espaços iguais, esquerda —
	# sempre a mesma resposta para o mesmo cenário (research R2).
	var caminhao := _npc("caminhao", Vector2(320.0, 200.0))
	var esporte := _npc("esporte", Vector2(320.0, 250.0))
	_atualizar([caminhao, esporte], 4)

	assert_int(caminhao.npc_drift.direcao).is_equal(-1).override_failure_message(
		"FR-015: margem neutra com espaços iguais não resolveu de forma estável"
	)
	caminhao.free()
	esporte.free()


func test_speed_identical_before_during_and_after_drift() -> void:
	# SC-014: nenhuma colisão, drift ou recuperação altera get_speed() —
	# igualdade exata em todas as amostras.
	var caminhao := _npc("caminhao", Vector2(324.0, 200.0))
	var esporte := _npc("esporte", Vector2(316.0, 250.0))
	var vel_caminhao: float = caminhao.get_speed()
	var vel_esporte: float = esporte.get_speed()

	_atualizar([caminhao, esporte], 1)
	assert_float(caminhao.get_speed()).is_equal(vel_caminhao).override_failure_message(
		"SC-014: velocidade do atingido mudou no impacto"
	)

	# Durante o drift ativo (força/duração escaladas — FR-014).
	_atualizar([caminhao, esporte], 12)
	assert_bool(caminhao.npc_drift.ativo()).is_true().override_failure_message(
		"FR-014: drift já terminou antes da amostra 'durante'"
	)
	assert_float(caminhao.get_speed()).is_equal(vel_caminhao).override_failure_message(
		"SC-014: velocidade do atingido mudou durante o drift"
	)

	# Depois: drift + recuperação completos (duração máx 0,9s + 1/1,4 s).
	_atualizar([caminhao, esporte], 300)
	assert_int(caminhao.npc_drift.fase).is_equal(NpcDriftState.Fase.NORMAL).override_failure_message(
		"FR-021: recuperação não completou em 5s"
	)
	assert_float(caminhao.get_speed()).is_equal(vel_caminhao).override_failure_message(
		"SC-014: velocidade do atingido mudou após a recuperação"
	)
	assert_float(esporte.get_speed()).is_equal(vel_esporte).override_failure_message(
		"SC-014: velocidade do causador mudou"
	)
	caminhao.free()
	esporte.free()
