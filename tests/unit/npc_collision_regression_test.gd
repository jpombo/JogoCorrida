extends GdUnitTestSuite

## SPEC-006 / T033 — regressão US9 (SC-011, SC-015, FR-042, FR-043):
## o jogo todo é preservado com o sistema NPC×NPC ativo:
## - NPC deslocado pela colisão NPC×NPC que toca o jogador → exatamente 1
##   evento `CollisionSystem.collision_occurred` e nenhum evento NPC×NPC
##   adicional (FR-037/FR-038, SC-015 — o detector do jogador é exclusivo do
##   SPEC-005 e ignora o jogador na avaliação NPC×NPC);
## - teto de 5 ativos com 100% dos pares avaliados (SC-011);
## - `npc_max_active` como projeção somente leitura do teto por dificuldade
##   do SPEC-004, configurável pela fonte existente (FR-042);
## - invariantes arcade: rotation == 0, velocidade de NPC intocada e nenhum
##   desvio estratégico (FR-043).
##
## A ordem dos sistemas por quadro espelha o wiring do `gameplay_manager`
## (T035, research R9): NPC×NPC antes do detector do jogador, para que o
## NPC já deslocado ocupe a posição final quando o SPEC-005 avaliar.

const BOUNDS := {"left": 248.0, "right": 392.0}

var sistema_npc: NpcCollisionSystem
var sistema_jogador: CollisionSystem
var jogador: PlayerVehicle
var eventos_npc: Array = []
var eventos_jogador: Array = []
var _ambiente_original: String = ""
var _teto_original: Dictionary = {}


func before_test() -> void:
	sistema_npc = NpcCollisionSystem.new()
	sistema_jogador = CollisionSystem.new()
	jogador = PlayerVehicle.new()
	eventos_npc.clear()
	eventos_jogador.clear()
	sistema_npc.npc_collision_occurred.connect(func(d): eventos_npc.append(d))
	sistema_jogador.collision_occurred.connect(func(d): eventos_jogador.append(d))
	# Originais da fonte única para restauração segura mesmo em falha (FR-042).
	_ambiente_original = GameConfig.current_environment_id
	_teto_original = GameConfig.traffic_max_visible_by_difficulty.duplicate()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.traffic_max_visible_by_difficulty = _teto_original
	jogador.free()
	sistema_npc = null
	sistema_jogador = null
	eventos_npc.clear()
	eventos_jogador.clear()


func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = GameConfig.NPC_HITBOX_SIZES[categoria_id]
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS


## Um quadro na ordem de wiring do jogo (T035): NPC×NPC primeiro, depois o
## detector do jogador — o contato visto no mesmo quadro do deslocamento.
func _quadro(npcs: Array) -> void:
	sistema_npc.update(1.0 / 60.0, npcs, _bounds)
	sistema_jogador.update(1.0 / 60.0, jogador, npcs, _bounds)


## US9-CA1 / SC-015 — A atinge B, B desloca à esquerda e encosta no jogador
## posicionado no trajeto: exatamente 1 evento do SPEC-005, atribuído a B,
## e nenhum evento NPC×NPC novo (o SPEC-005 não contamina o sistema novo).
func test_displaced_npc_touching_player_emits_exactly_one_player_event() -> void:
	jogador.position = Vector2(324.0, 240.0)
	jogador.controller.speed = 100.0
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var npcs := [a, b]

	for i in range(90):
		_quadro(npcs)

	assert_bool(b.position.x < 356.0).is_true().override_failure_message(
		"sanidade: B não foi deslocado pela colisão NPC×NPC"
	)
	assert_int(eventos_npc.size()).is_equal(1).override_failure_message(
		"FR-037: contato com o jogador gerou evento NPC×NPC (%d)" % eventos_npc.size()
	)
	assert_int(eventos_jogador.size()).is_equal(1).override_failure_message(
		"SC-015: contato deslocado↔jogador gerou %d eventos SPEC-005 (esperado 1)"
		% eventos_jogador.size()
	)
	assert_bool(eventos_jogador[0].npc == b).is_true().override_failure_message(
		"SC-015: o evento SPEC-005 não foi do NPC deslocado"
	)
	a.free()
	b.free()


## US9-CA2 / SC-011 — 5 NPCs ativos permanecem ativos em 100% dos quadros e
## todos os C(5,2) = 10 pares são avaliados dentro do intervalo de
## reavaliação (o teto nunca é excedido pelo sistema).
func test_five_active_npcs_keep_all_pairs_evaluated() -> void:
	var npcs := [
		_npc("passeio", Vector2(300.0, 120.0)),
		_npc("passeio", Vector2(340.0, 180.0)),
		_npc("caminhao", Vector2(280.0, 240.0)),
		_npc("esporte", Vector2(360.0, 300.0)),
		_npc("utilitario", Vector2(310.0, 360.0)),
	]

	var todos_ativos: bool = true
	for i in range(40):  # 40 quadros > npc_reevaluation_interval (0,25 s)
		_quadro(npcs)
		for npc in npcs:
			if not npc.is_active():
				todos_ativos = false

	assert_bool(todos_ativos).is_true().override_failure_message(
		"SC-011: algum NPC saiu de ativo durante os quadros"
	)

	assert_int(npcs.size()).is_equal(GameConfig.npc_max_active()).override_failure_message(
		"SC-011: cenário não corresponde ao teto vigente"
	)
	assert_int(sistema_npc.total_pares()).is_equal(10).override_failure_message(
		"SC-011: 5 ativos exigem 10 pares, encontrados %d" % sistema_npc.total_pares()
	)
	assert_int(sistema_npc.pares_avaliados()).is_equal(10).override_failure_message(
		"SC-011: pares avaliados %d/10" % sistema_npc.pares_avaliados()
	)
	for npc in npcs:
		npc.free()


## US9-CA3 / FR-042 — `npc_max_active` é projeção somente leitura do teto
## por dificuldade do SPEC-004: muda ao trocar de ambiente e ao reconfigurar
## a fonte única, sem valor próprio armazenado no sistema.
func test_npc_max_active_is_read_only_projection() -> void:
	GameConfig.current_environment_id = "ICE"
	assert_int(sistema_npc.npc_max_active()).is_equal(5).override_failure_message(
		"FR-042: Gelo deveria projetar teto 5"
	)

	GameConfig.traffic_max_visible_by_difficulty[4] = 3
	assert_int(sistema_npc.npc_max_active()).is_equal(3).override_failure_message(
		"FR-042: teto não seguiu a reconfiguração da fonte única"
	)


## US9-CA4 / FR-043 — arcade previsível: após colisões NPC×NPC em cadeia,
## nenhum veículo rotacionou, nenhuma velocidade mudou e nenhum desvio
## estratégico (ultrapassagem automática) foi disparado.
func test_arcade_invariants_after_collisions() -> void:
	var a := _npc("esporte", Vector2(358.0, 278.0))
	var b := _npc("passeio", Vector2(356.0, 240.0))
	var c := _npc("caminhao", Vector2(328.0, 240.0))
	var d := _npc("esporte", Vector2(299.0, 240.0))
	var npcs := [a, b, c, d]

	var velocidades_antes: Dictionary = {}
	for npc in npcs:
		velocidades_antes[npc] = npc.get_speed()

	for i in range(90):
		_quadro(npcs)

	assert_int(eventos_npc.size()).is_greater(0).override_failure_message(
		"sanidade: nenhuma colisão NPC×NPC ocorreu no cenário"
	)
	for npc in npcs:
		var id: int = npc.get_instance_id()
		assert_float(npc.rotation).is_equal(0.0).override_failure_message(
			"FR-043: veículo rotacionou (instance %d)" % id
		)
		assert_float(npc.get_speed()).is_equal(velocidades_antes[npc]).override_failure_message(
			"FR-043: velocidade de NPC alterada (instance %d)" % id
		)
		assert_bool(npc.overtake.ativo()).is_false().override_failure_message(
			"FR-043: desvio estratégico disparado (instance %d)" % id
		)
	for npc in npcs:
		npc.free()
