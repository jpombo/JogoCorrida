extends GdUnitTestSuite

## SPEC-006 / T042 — validação de nascimento (FR-028–FR-031, SC-010,
## contracts/spawn_validation.md):
## - regra 1: nenhum nascimento sobreposto (folga < traffic_min_separation
##   nos dois eixos) → recusa, não adiamento;
## - regra 2: mesma trajetória a menos de npc_spawn_safety_distance → recusa;
## - regra 3: encontro dentro da janela de atividade (mesma R1 da US2) →
##   recusa; encontro somente APÓS o descarte de um dos dois → aceito;
## - fluxo do TrafficManager (FR-029): faixa própria recusada → tenta as
##   demais faixas; esgotadas → candidato adiado e revalidado no quadro
##   seguinte com as posições atualizadas, sem esperar o próximo intervalo.
##
## Os cenários derivam as folgas dos parâmetros de GameConfig e carregam
## asserções de sanidade: se a configuração mudar, o teste falha dizendo que
## o cenário deixou de isolar a regra pretendida.

const LEFT: float = 248.0
const RIGHT: float = 392.0
## Scroll da estrada nos testes do validador — precisa ser > 0 para os
## tempos de descarte serem finitos, e é a mesma velocidade usada no
## `_primar` e no `road.scroll_speed` dos testes de fluxo.
const ESTRADA: float = 80.0
const DELTA: float = 1.0 / 60.0

var sistema: NpcCollisionSystem
## Tipada na subclasse para permitir `categoria_fixa` (sorteio determinístico).
var manager: ManagerComCategoriaFixa
var road: Road


## Dublê mínimo de Road (mesmo recorte do test_traffic_manager: só o que o
## manager consome — `scroll_speed` e `get_boundaries_for_player_y`).
class FakeRoad:
	extends Road

	var left: float = 248.0
	var right: float = 392.0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func get_boundaries_for_player_y(_y: float) -> Dictionary:
		return {"left": left, "right": right}

	func get_left_boundary() -> float:
		return left

	func get_right_boundary() -> float:
		return right


## Manager com categoria de nascimento fixa: o sorteio ponderado do FR-010
## embaralharia a faixa pretendida e os cenários de faixa própria/alternativa
## ficariam não determinísticos.
class ManagerComCategoriaFixa:
	extends TrafficManager

	var categoria_fixa: TrafficData = null

	func _sortear_categoria() -> TrafficData:
		return categoria_fixa


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	manager = ManagerComCategoriaFixa.new()
	manager.setup(_make_categories())
	road = FakeRoad.new()
	road.scroll_speed = ESTRADA


func after_test() -> void:
	manager.queue_free()
	if is_instance_valid(road):
		road.free()
	sistema = null
	road = null


func _make_categories() -> Dictionary:
	var categories: Dictionary = {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categories[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	return categories


func _bounds(_y: float) -> Dictionary:
	return {"left": LEFT, "right": RIGHT}


## Alimenta o sistema (mesma ordem do gameplay: o nascimento consulta a
## snapshot do quadro anterior) e fixa a velocidade da estrada usada pelos
## tempos de descarte da regra da janela.
func _primar(npcs: Array) -> void:
	sistema.update(DELTA, npcs, _bounds, ESTRADA)


## Categoria para os testes puros do validador, com a hitbox do sistema —
## candidata e ativos são medidos pela mesma régua (FR-010).
func _categoria(id: String) -> TrafficData:
	var cat := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	cat.size = GameConfig.NPC_HITBOX_SIZES[id]
	return cat


func _validar(id: String, x: float, y: float) -> Dictionary:
	return sistema.validar_spawn(_categoria(id), x, y, _bounds(y))


func _npc(id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = _categoria(id)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


## Réplica das faixas por velocidade do TrafficManager (ajuste 5): a posição
## de cada faixa reservada, da mais rápida (esquerda) à mais lenta (direita),
## na largura da pista do dublê e da MEIA-LARGURA da categoria.
func _faixas(m: TrafficManager, categoria: TrafficData) -> Array[float]:
	var distintas: Array[float] = []
	for id in m.categories:
		var velocidade: float = m.categories[id].max_speed
		if not distintas.has(velocidade):
			distintas.append(velocidade)
	distintas.sort()
	var min_x: float = LEFT + categoria.size.x * 0.5
	var max_x: float = RIGHT - categoria.size.x * 0.5
	if distintas.size() <= 1:
		return [(min_x + max_x) * 0.5]
	var faixas: Array[float] = []
	for ordem in distintas.size():
		faixas.append(min_x + (max_x - min_x) * float(ordem) / float(distintas.size() - 1))
	return faixas


## Faixa reservada da própria categoria — mesma fórmula do
## `_slot_da_categoria` (ordem 0 = mais rápido = extremo esquerdo).
func _faixa_propria(m: TrafficManager, categoria: TrafficData) -> float:
	var distintas: Array[float] = []
	for id in m.categories:
		var velocidade: float = m.categories[id].max_speed
		if not distintas.has(velocidade):
			distintas.append(velocidade)
	distintas.sort()
	var faixas := _faixas(m, categoria)
	if faixas.size() <= 1:
		return faixas[0]
	var ordem: int = distintas.size() - 1 - distintas.find(categoria.max_speed)
	return faixas[ordem]


## US7-CA2 / FR-031 / SC-010 — regra 1: um nascimento que colidiria
## imediatamente (folga negativa nos dois eixos) é recusado. A recusa não é
## adiamento: `adiar` só existe no esgotamento de faixas (FR-029).
func test_rule1_rejects_overlapping_birth() -> void:
	var y_cand: float = -100.0
	# 10 px centro-a-centro: os dois retângulos de 42 px se sobrepõem.
	var ativo := _npc("passeio", Vector2(320.0, y_cand + 10.0))
	_primar([ativo])

	var r := _validar("passeio", 320.0, y_cand)

	assert_bool(r.aceito).is_false().override_failure_message(
		"FR-031/SC-010: nascimento sobreposto foi aceito"
	)
	assert_bool(r.adiar).is_false().override_failure_message(
		"recusa de posição não pode virar adiamento (adiar só no esgotamento)"
	)
	ativo.free()


## US7-CA1 / FR-028 — regra 2: mesma trajetória com a distância longitudinal
## entre as hitboxes dentro de npc_spawn_safety_distance (e acima da
## separação mínima, para isolar esta regra) → recusa.
func test_rule2_rejects_inside_safety_distance() -> void:
	var folga: float = GameConfig.npc_spawn_safety_distance * 0.5
	assert_float(folga).is_greater_equal(
		GameConfig.traffic_min_separation
	).override_failure_message("sanidade: cenário precisa passar pela regra 1")
	assert_float(folga).is_less(
		GameConfig.npc_spawn_safety_distance
	).override_failure_message("sanidade: cenário precisa cair na regra 2")

	var y_cand: float = -100.0
	var hit: Vector2 = GameConfig.NPC_HITBOX_SIZES["passeio"]
	var y_ativo: float = y_cand + hit.y * 0.5 + folga + hit.y * 0.5
	var ativo := _npc("passeio", Vector2(320.0, y_ativo))
	_primar([ativo])

	var r := _validar("passeio", 320.0, y_cand)

	assert_bool(r.aceito).is_false().override_failure_message(
		"FR-028: nascimento a menos de npc_spawn_safety_distance foi aceito"
	)
	ativo.free()


## US7-CA3 / FR-030 / SC-010 — regra 3: o encontro (caminhão nascente
## alcançando o esporte) cabe na janela de atividade conjunta → recusa.
## O esporte é mais rápido e está ABAIXO (traseiro), fechando a 24 un/s.
func test_rule3_rejects_encounter_within_window() -> void:
	var folga: float = GameConfig.npc_spawn_safety_distance + 5.0
	var esporte := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["esporte"])
	var caminhao := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["caminhao"])
	var fechamento: float = esporte.max_speed - caminhao.max_speed
	var ttc: float = folga / fechamento

	assert_float(folga).is_greater_equal(
		GameConfig.npc_spawn_safety_distance
	).override_failure_message("sanidade: cenário precisa passar pela regra 2")
	assert_float(fechamento).is_greater(
		GameConfig.npc_min_relative_speed
	).override_failure_message("sanidade: fechamento relevante para a R1")
	assert_float(ttc).is_less_equal(
		GameConfig.npc_collision_prediction_horizon
	).override_failure_message(
		"sanidade: encontro fora do horizonte — a regra 3 não dispararia"
	)

	var y_cand: float = -100.0
	var hit_c: Vector2 = GameConfig.NPC_HITBOX_SIZES["caminhao"]
	var hit_e: Vector2 = GameConfig.NPC_HITBOX_SIZES["esporte"]
	var y_ativo: float = y_cand + hit_c.y * 0.5 + folga + hit_e.y * 0.5
	var ativo := _npc("esporte", Vector2(320.0, y_ativo))
	_primar([ativo])

	var r := _validar("caminhao", 320.0, y_cand)

	assert_bool(r.aceito).is_false().override_failure_message(
		"FR-030/SC-010: conflito dentro da janela de atividade não foi identificado"
	)
	ativo.free()


## US7-CA4 / FR-030 / SC-010 — o encontro que só ocorreria depois do
## descarte do ativo (pelo topo, logo após nascer) NÃO é colisão ativa e
## não bloqueia o nascimento.
func test_rule3_accepts_post_discard_encounter() -> void:
	var folga: float = GameConfig.npc_spawn_safety_distance + 5.0
	var esporte := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["esporte"])
	var caminhao := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["caminhao"])
	var fechamento: float = esporte.max_speed - caminhao.max_speed
	var ttc: float = folga / fechamento
	var janela_descarte: float = (
		GameConfig.npc_active_area_margin / absf(ESTRADA - esporte.max_speed)
	)
	assert_float(janela_descarte).is_less(ttc).override_failure_message(
		"sanidade: o descarte do ativo precisa ocorrer antes do encontro"
	)

	var y_cand: float = -100.0
	var hit_c: Vector2 = GameConfig.NPC_HITBOX_SIZES["caminhao"]
	var hit_e: Vector2 = GameConfig.NPC_HITBOX_SIZES["esporte"]
	var y_ativo: float = y_cand + hit_c.y * 0.5 + folga + hit_e.y * 0.5
	var ativo := _npc("esporte", Vector2(320.0, y_ativo))
	# Nasceu agora: pelo topo (saiu do nascimento) ele é descartado antes de
	# alcançar a posição em que o encontro ocorreria.
	ativo.y_nascimento = y_ativo
	_primar([ativo])

	var r := _validar("caminhao", 320.0, y_cand)

	assert_bool(r.aceito).is_true().override_failure_message(
		"FR-030/SC-010: encontro pós-descarte bloqueou o nascimento"
	)
	ativo.free()


## Regra base / contrato — nascimento longe de qualquer ativo (mesma
## trajetória mas sem fechamento, e também com a lista vazia) é aceito, e o
## veredito tem exatamente as chaves do contrato.
func test_far_spawn_accepted_with_contract_shape() -> void:
	var ativo := _npc("passeio", Vector2(320.0, 200.0))
	_primar([ativo])

	var r := _validar("passeio", 320.0, -100.0)

	assert_dict(r).contains_keys(
		["aceito", "x", "y", "adiar"]
	).override_failure_message("contrato: validar_spawn deve devolver {aceito, x, y, adiar}")
	assert_bool(r.aceito).is_true().override_failure_message(
		"nascimento longe de qualquer ativo foi recusado"
	)
	assert_bool(r.adiar).is_false().override_failure_message(
		"posição válida não pode ser adiada"
	)

	_primar([])
	var livre := _validar("passeio", 320.0, -100.0)
	assert_bool(livre.aceito).is_true().override_failure_message(
		"sem ativos o nascimento deve ser aceito"
	)
	ativo.free()


## US7-CA1 / FR-028, FR-029 / T044 — o manager consulta o validador: a faixa
## própria passa pela separação e pela ordenação do SPEC-004 (fantasma fora
## do manager, folga ≥ traffic_min_separation) mas é recusada pela regra 2,
## e o nascimento acontece em OUTRA faixa no MESMO quadro.
func test_manager_uses_validator_and_changes_lane() -> void:
	manager.categoria_fixa = manager.categories["esporte"]
	manager.validador = sistema

	var esporte: TrafficData = manager.categories["esporte"]
	var faixas := _faixas(manager, esporte)
	var propria := _faixa_propria(manager, esporte)
	var folga: float = GameConfig.npc_spawn_safety_distance - GameConfig.traffic_min_separation
	assert_float(folga).is_greater_equal(
		GameConfig.traffic_min_separation
	).override_failure_message("sanidade: cenário precisa passar pela separação do SPEC-004")
	assert_float(folga).is_less(
		GameConfig.npc_spawn_safety_distance
	).override_failure_message("sanidade: cenário precisa cair na regra 2 do validador")

	var y_cand: float = -esporte.size.y - GameConfig.traffic_spawn_fill_distance
	var hit_c: Vector2 = GameConfig.NPC_HITBOX_SIZES["caminhao"]
	var hit_e: Vector2 = GameConfig.NPC_HITBOX_SIZES["esporte"]
	var y_fantasma: float = y_cand + hit_e.y * 0.5 + folga + hit_c.y * 0.5
	var fantasma := _npc("caminhao", Vector2(propria, y_fantasma))
	_primar([fantasma])

	manager.update(DELTA, road)

	assert_int(manager.active_count).is_equal(1).override_failure_message(
		"FR-028: faixa própria recusada pelo validador não tentou as demais faixas"
	)
	assert_int(manager.spawn_pendente().size()).is_zero().override_failure_message(
		"havia faixa alternativa livre — o nascimento não deveria adiar"
	)
	var nasceu: TrafficVehicle = manager.active_vehicles[0]
	assert_bool(
		not is_equal_approx(nasceu.position.x, propria)
	).is_true().override_failure_message(
		"FR-029: nasceu na faixa própria que o validador recusou (x=%.1f)" % nasceu.position.x
	)
	assert_float(nasceu.position.y).is_less_equal(
		-esporte.size.y
	).override_failure_message("I3: nascimento dentro da área visível")
	fantasma.free()


## US7-CA1 / FR-029 / SC-010 / T045 — todas as faixas indisponíveis neste
## quadro → o candidato é ADIADO (não some), e nasce no quadro seguinte
## quando as faixas liberam, sem esperar o próximo intervalo de spawn.
func test_manager_defers_blocked_birth_to_next_frame() -> void:
	manager.categoria_fixa = manager.categories["caminhao"]
	manager.validador = sistema
	var caminhao: TrafficData = manager.categories["caminhao"]

	# Um bloqueador em cada faixa, logo acima da linha de nascimento (fora
	# da contagem de "na pista" ou exatamente no mínimo — nos dois casos o
	# enchimento do SPEC-004 vale).
	var bloqueadores: Array[TrafficVehicle] = []
	for x in _faixas(manager, caminhao):
		var v := manager._obter_do_pool()
		v.activate(caminhao, x, -100.0)
		manager.active_vehicles.append(v)
		bloqueadores.append(v)

	manager.update(DELTA, road)

	assert_int(manager.spawn_pendente().size()).is_greater(0).override_failure_message(
		"FR-029: sem faixa livre o nascimento deveria ser adiado"
	)
	assert_int(manager.active_count).is_equal(
		bloqueadores.size()
	).override_failure_message("SC-010: nasceu veículo com todas as faixas bloqueadas")

	for v in bloqueadores:
		v.deactivate()
	_primar(manager.active_vehicles_snapshot)
	manager.update(DELTA, road)

	assert_int(manager.active_count).is_equal(1).override_failure_message(
		"FR-029: nascimento adiado não nasceu no quadro seguinte"
	)
	assert_int(manager.spawn_pendente().size()).is_zero().override_failure_message(
		"FR-029: pendente deveria limpar após o nascimento"
	)


## US7-CA1 / FR-029 / SC-010 / T044+T045 — o validador recusa TODAS as
## faixas (fantasmas passam pela separação do SPEC-004) → adiamento; com as
## posições atualizadas no quadro seguinte, a revalidação aceita e o
## nascimento ocorre — sem perda até o próximo intervalo.
func test_manager_revalidates_pending_with_updated_positions() -> void:
	manager.categoria_fixa = manager.categories["esporte"]
	manager.validador = sistema
	var esporte: TrafficData = manager.categories["esporte"]
	var folga: float = GameConfig.npc_spawn_safety_distance - GameConfig.traffic_min_separation
	var y_cand: float = -esporte.size.y - GameConfig.traffic_spawn_fill_distance
	var hit_c: Vector2 = GameConfig.NPC_HITBOX_SIZES["caminhao"]
	var hit_e: Vector2 = GameConfig.NPC_HITBOX_SIZES["esporte"]
	var y_fantasma: float = y_cand + hit_e.y * 0.5 + folga + hit_c.y * 0.5

	# Fantasmas fora do manager (só o validador os vê) em TODAS as faixas.
	var fantasmas: Array = []
	for x in _faixas(manager, esporte):
		var g := _npc("caminhao", Vector2(x, y_fantasma))
		fantasmas.append(g)

	_primar(fantasmas)
	manager.update(DELTA, road)

	assert_int(manager.spawn_pendente().size()).is_greater(0).override_failure_message(
		"FR-029: validador recusou todas as faixas e o nascimento não adiou"
	)
	assert_int(manager.active_count).is_zero().override_failure_message(
		"SC-010: nasceu com conflito dentro da janela"
	)

	# Posições atualizadas (o npc update do quadro correu) → revalidação.
	for g in fantasmas:
		g.position.y = 300.0
	_primar(fantasmas)
	manager.update(DELTA, road)

	assert_int(manager.active_count).is_equal(1).override_failure_message(
		"FR-029: pendente não foi revalidado com as posições atualizadas"
	)
	assert_int(manager.spawn_pendente().size()).is_zero().override_failure_message(
		"FR-029: pendente não limou após o nascimento"
	)
	for g in fantasmas:
		g.free()
