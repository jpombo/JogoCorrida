extends GdUnitTestSuite

## T024, T030, T031, T036, T037 e T056 — controlador de decoração.
##
## Dublê de Road com apenas a superfície consumida pelo contrato (§9), como em
## `test_traffic_manager.gd`. Os casos cobrem D1 a D8, SC-009, SC-021, FR-041,
## FR-042, FR-043, FR-051, FR-058/FR-059 e a frequência observada dos
## percentuais declarados (FR-036, FR-037).

const ESQ: int = DecorationManager.Side.LEFT
const DIR: int = DecorationManager.Side.RIGHT

var manager: DecorationManager
var road: FakeRoad
var speed_original: float


class FakeRoad:
	extends Road

	var left: float = 248.0
	var right: float = 392.0

	func _init(p_left: float = 248.0, p_right: float = 392.0) -> void:
		left = p_left
		right = p_right

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


func before_test() -> void:
	speed_original = GameConfig.decoration_speed_multiplier
	manager = DecorationManager.new()
	road = FakeRoad.new()
	road.scroll_speed = 80.0
	manager.setup(GameConfig.DECORATION_LIBRARIES)
	manager.set_environment("FOREST")


func after_test() -> void:
	GameConfig.decoration_speed_multiplier = speed_original
	manager.free()
	manager = null
	road = null


func _rodar(segundos: float) -> void:
	var total: int = int(segundos * 60.0)
	for i in total:
		manager.update(1.0 / 60.0, road)


func _biblioteca(ambiente: String) -> Array[DecorationData]:
	var lib: Array[DecorationData] = []
	for data in manager.libraries[ambiente]:
		lib.append(data)
	return lib


func _meia_largura(e: DecorationElement) -> float:
	return e.get_dimensao().x * 0.5


## T024 / D1 — a biblioteca em uso é a do ambiente vigente.
func test_active_elements_come_from_current_library() -> void:
	_rodar(30.0)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"D1: nenhum elemento nasceu em 30 s"
	)

	var permitidos: Array[String] = []
	for data in _biblioteca("FOREST"):
		permitidos.append(data.asset)

	for e in manager.active_elements:
		assert_array(permitidos).contains(
			e.data.asset
		).override_failure_message("D1: elemento de outro ambiente na tela")


## T024 / SC-021 — todo elemento fica fora da área trafegável + margem de segurança.
func test_safety_margin_respected() -> void:
	_rodar(40.0)
	var margem: float = GameConfig.decoration_safety_margin
	for e in manager.active_elements:
		var bounds: Dictionary = road.get_boundaries_for_player_y(e.position.y)
		var meio: float = _meia_largura(e)
		if e.side == ESQ:
			assert_float(e.position.x + meio).is_less_equal(
				float(bounds["left"]) - margem
			).override_failure_message("SC-021: elemento invadindo a estrada pela esquerda")
		else:
			assert_float(e.position.x - meio).is_greater_equal(
				float(bounds["right"]) + margem
			).override_failure_message("SC-021: elemento invadindo a estrada pela direita")


## T024 / FR-041, FR-042 — nasce acima da área visível e já fora da estrada.
func test_birth_happens_above_visible_area() -> void:
	var nasceu_invalido: int = 0
	var nasceram: int = 0
	for i in 600:
		manager.update(1.0 / 60.0, road)
		for e in manager.active_elements:
			if not e.ja_visto:
				nasceram += 1
				# `ja_visto` só vira true quando há pixel visível; logo, quem
				# ainda não foi visto está acima do topo (y < 0).
				if e.position.y > 0.0:
					nasceu_invalido += 1

	assert_int(nasceram).is_greater(0).override_failure_message(
		"FR-041: nenhum elemento nasceu"
	)
	assert_int(nasceu_invalido).is_zero().override_failure_message(
		"FR-041: elemento nasceu dentro da área visível"
	)


## T024 / D4 — reciclagem por qualquer borda, sem acumular objeto.
func test_recycles_by_any_border() -> void:
	_rodar(120.0)
	assert_int(manager.pool_size).is_greater(0).override_failure_message(
		"D4: pool nunca foi criado"
	)
	assert_int(manager.active_count).is_less(
		manager.pool_size
	).override_failure_message("D4: nada foi reciclado em 120 s")
	assert_int(manager.active_count).is_less_equal(
		40
	).override_failure_message("SC-010: elementos ativos sem limite")


## T024 / D6, D7 — não repetível nunca sai duas vezes seguidas; repetível
## para em decoration_tree_repeat_limit.
func test_repeat_rules_on_selection_sequence() -> void:
	var lib: Array[DecorationData] = _biblioteca("FOREST")
	var sequencia: Array[String] = []
	for i in 300:
		var escolhido: DecorationData = manager._escolher_asset(lib, ESQ)
		sequencia.append(escolhido.asset)

	var seguidas: int = 1
	for i in range(1, sequencia.size()):
		if sequencia[i] == sequencia[i - 1]:
			seguidas += 1
			assert_int(seguidas).is_less_equal(
				GameConfig.decoration_tree_repeat_limit
			).override_failure_message("D7: sequência de repetição acima do limite")
		else:
			seguidas = 1

		if not _e_repetivel(lib, sequencia[i]):
			assert_bool(sequencia[i] != sequencia[i - 1]).is_true().override_failure_message(
				"D6: não repetível apareceu duas vezes seguidas"
			)


func _e_repetivel(lib: Array[DecorationData], asset: String) -> bool:
	for data in lib:
		if data.asset == asset:
			return data.repeatable
	return false


## T030 / SC-009 — condução normal mantém ao menos 3 elementos por lado e
## ao menos 2 profundidades populadas.
func test_minimum_elements_and_depths_per_side() -> void:
	var amostras: int = 0
	var abaixo_de_tres: int = 0
	var total_esq: int = 0
	var total_dir: int = 0
	var profundidades := {ESQ: {}, DIR: {}}

	_rodar(12.0)  # aquecimento: tela cheia antes de medir
	for i in 1800:  # 30 s medidos
		manager.update(1.0 / 60.0, road)
		amostras += 1
		var n_esq: int = 0
		var n_dir: int = 0
		for e in manager.active_elements:
			profundidades[e.side][e.depth_index] = true
			if e.side == ESQ:
				n_esq += 1
			else:
				n_dir += 1
		total_esq += n_esq
		total_dir += n_dir
		if n_esq < 3 or n_dir < 3:
			abaixo_de_tres += 1

	assert_float(float(total_esq) / float(amostras)).is_greater_equal(
		3.0
	).override_failure_message("SC-009: média do lado esquerdo abaixo de 3 elementos")
	assert_float(float(total_dir) / float(amostras)).is_greater_equal(
		3.0
	).override_failure_message("SC-009: média do lado direito abaixo de 3 elementos")
	assert_float(float(amostras - abaixo_de_tres) / float(amostras)).is_greater_equal(
		0.9
	).override_failure_message("SC-009: mais de 10% dos quadros com menos de 3 por lado")
	assert_int(profundidades[ESQ].size()).is_greater_equal(2).override_failure_message(
		"SC-009: lado esquerdo com menos de 2 profundidades"
	)
	assert_int(profundidades[DIR].size()).is_greater_equal(2).override_failure_message(
		"SC-009: lado direito com menos de 2 profundidades"
	)


## T031 / D5, SC-022 — com a estrada parada nada se move, nada nasce e nada morre.
func test_zero_scroll_freezes_everything() -> void:
	_rodar(30.0)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"D5: preciso de elementos para congelar"
	)

	var antes: Array[Vector2] = []
	for e in manager.active_elements:
		antes.append(e.position)
	var pool_antes: int = manager.pool_size
	var ativos_antes: int = manager.active_count

	road.scroll_speed = 0.0
	for i in 60:
		manager.update(1.0 / 60.0, road)

	var indice: int = 0
	for e in manager.active_elements:
		assert_vector(e.position).is_equal(
			antes[indice]
		).override_failure_message("D5: elemento se moveu com a estrada parada")
		indice += 1
	assert_int(manager.pool_size).is_equal(
		pool_antes
	).override_failure_message("SC-022: nasceu elemento com scroll_speed 0.0")
	assert_int(manager.active_count).is_equal(
		ativos_antes
	).override_failure_message("D5: elemento foi reciclado com a estrada parada")


## T031 / FR-039 — o deslocamento usa decoration_speed_multiplier.
func test_scroll_uses_speed_multiplier() -> void:
	_rodar(20.0)
	var alvo: DecorationElement = null
	for e in manager.active_elements:
		if alvo == null or e.position.y < alvo.position.y:
			alvo = e
	assert_object(alvo).is_not_null().override_failure_message(
		"FR-039: preciso de um elemento para medir"
	)

	var y0: float = alvo.position.y
	road.scroll_speed = 60.0
	manager.update(1.0 / 60.0, road)
	var esperado: float = 60.0 * GameConfig.decoration_speed_multiplier / 60.0
	assert_float(alvo.position.y - y0).is_equal_approx(esperado, 0.01).override_failure_message(
		"FR-039: deslocamento fora de decoration_speed_multiplier"
	)


## T031 / D2, FR-051 — reposicionamento contínuo ao estreitar, sem invadir a pista.
func test_continuous_reposition_when_road_narrows() -> void:
	road.right = 424.0  # 4 vias
	_rodar(40.0)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"D2: preciso de elementos na pista larga"
	)

	road.right = 392.0  # 2 vias

	# `manager.update()` reposiciona TODOS os elementos a cada chamada, então a
	# medição acompanha a lista inteira de uma vez. Medir só o elemento da vez
	# fazia o teste falhar sempre que o primeiro da lista era da ESQ: o
	# deslocamento dele já tinha acontecido no update do laço anterior.
	var acompanhados: Dictionary = {}  # elemento -> x do quadro anterior
	for elem in manager.active_elements:
		if elem.side == DIR:
			acompanhados[elem] = elem.position.x

	var maior_passo: float = 0.0
	var reposicionados: Dictionary = {}
	for quadro in 10:
		manager.update(1.0 / 60.0, road)
		for elemento in acompanhados.keys():
			var atual: DecorationElement = elemento as DecorationElement
			if not is_instance_valid(atual) or not atual.active:
				acompanhados.erase(elemento)
				reposicionados.erase(elemento)
				continue
			var x_anterior: float = acompanhados[elemento]
			var deslocamento: float = x_anterior - atual.position.x
			if deslocamento > 0.01:
				reposicionados[elemento] = true
				maior_passo = maxf(maior_passo, deslocamento)
			acompanhados[elemento] = atual.position.x

	var moveu: int = reposicionados.size()

	assert_int(moveu).is_greater(0).override_failure_message(
		"FR-051: elementos não foram reposicionados ao estreitar"
	)
	assert_float(maior_passo).is_less_equal(
		GameConfig.decoration_depth_spacing
	).override_failure_message("FR-051: salto lateral maior que uma profundidade")

	var margem: float = GameConfig.decoration_safety_margin
	for e in manager.active_elements:
		if e.side == DIR:
			assert_float(e.position.x - _meia_largura(e)).is_greater_equal(
				road.right + margem
			).override_failure_message("SC-021: elemento entrou na pista ao estreitar")


## T036 / FR-058, FR-059, SC-012, SC-013 — composição continua durante a
## transição 2 <-> 4 vias, sem lacuna nem elemento fora do campo de visão.
func test_composition_survives_lane_transition() -> void:
	GameConfig.decoration_speed_multiplier = 1.0  # cenário V16
	_rodar(40.0)

	road.right = 424.0  # alarga para 4 vias
	_rodar(6.0)
	road.right = 392.0  # reduz para 2 vias
	_rodar(6.0)

	assert_int(manager.active_count).is_greater_equal(
		2
	).override_failure_message("SC-012: decoração desapareceu durante a transição")

	var fora_da_visao: int = 0
	for e in manager.active_elements:
		var x: float = e.position.x
		if x < 0.0 or x > 640.0:
			fora_da_visao += 1
	assert_int(fora_da_visao).is_zero().override_failure_message(
		"SC-013: elemento saiu do campo de visão durante a transição"
	)
	assert_int(manager.active_count).is_greater(
		0
	).override_failure_message("SC-012: sem elementos de um dos lados após a transição")


## T037 / D1, SC-008 — trocar ambiente limpa a tela e emite o sinal.
func test_set_environment_replaces_all_elements() -> void:
	var emissoes: Array = []
	manager.environment_changed.connect(
		func(novo: String, antigo: String) -> void: emissoes.append([novo, antigo])
	)

	_rodar(30.0)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"D1: preciso de elementos antes da troca"
	)

	manager.set_environment("DESERT")
	assert_int(manager.active_count).is_zero().override_failure_message(
		"SC-008: elementos do ambiente anterior permaneceram na tela"
	)
	assert_int(emissoes.size()).is_equal(1).override_failure_message(
		"D1: environment_changed não emitido"
	)
	assert_array(emissoes[0]).is_equal(
		["DESERT", "FOREST"]
	).override_failure_message("D1: sinal com identificadores errados")

	_rodar(30.0)
	var permitidos: Array[String] = []
	for data in _biblioteca("DESERT"):
		permitidos.append(data.asset)
	assert_int(manager.active_count).is_greater(0).override_failure_message(
		"D1: novo ambiente não nasceu"
	)
	for e in manager.active_elements:
		assert_array(permitidos).contains(
			e.data.asset
		).override_failure_message("D1: elemento do ambiente antigo sobreviveu à troca")


## T056 / FR-036, FR-037 — a frequência observada se aproxima do percentual
## declarado em partidas longas, com D6 e D7 ativos.
func test_observed_frequency_matches_declared() -> void:
	var tolerancia: float = 0.03
	for ambiente in ["PLAINS", "DESERT", "FOREST"]:
		var lib: Array[DecorationData] = _biblioteca(ambiente)
		var contagem := {}
		var total: int = 5000
		for i in total:
			var escolhido: DecorationData = manager._escolher_asset(lib, ESQ)
			contagem[escolhido.asset] = int(contagem.get(escolhido.asset, 0)) + 1

		for data in lib:
			var observado: float = float(contagem.get(data.asset, 0)) / float(total)
			assert_float(absf(observado - data.weight / 100.0)).is_less_equal(
				tolerancia
			).override_failure_message(
				"FR-036: %s/%s declarou %.1f%% e observou %.1f%%"
				% [ambiente, data.asset, data.weight, observado * 100.0]
			)


## T056 / SC-014 — em ICE a única árvore repetível tem teto de ~90,9%
## (10 de cada 11 nascimentos); a frequência fica perto desse teto, não dos 96%.
func test_ice_frequency_respects_repeat_ceiling() -> void:
	var lib: Array[DecorationData] = _biblioteca("ICE")
	var contagem := {}
	var total: int = 5000
	for i in total:
		var escolhido: DecorationData = manager._escolher_asset(lib, ESQ)
		contagem[escolhido.asset] = int(contagem.get(escolhido.asset, 0)) + 1

	var arvore: float = float(contagem.get("gelo_arvore", 0)) / float(total)
	assert_float(arvore).is_greater_equal(0.87).override_failure_message(
		"SC-014: árvore de Gelo caiu muito abaixo do teto (~90,9%)"
	)
	assert_float(arvore).is_less_equal(0.93).override_failure_message(
		"SC-014: árvore de Gelo ultrapassou o teto de ~90,9%"
	)
	assert_float(
		float(contagem.get("gelo_boneco", 0)) / float(total)
	).is_greater(0.0).override_failure_message("SC-014: excedente não foi redistribuído")


## T058 / FR-038, FR-040, SC-026 — em 10 minutos contínuos e QUADRO A QUADRO:
## - elementos da MESMA profundidade (mesmo lado) mantêm separação de pelo menos
##   `decoration_spacing_min` na direção de deslocamento;
## - 0 elementos são visualizados sobre a área trafegável ou dentro da
##   `decoration_safety_margin`;
## - todo elemento ativo se desloca exatamente uma vez por quadro (FR-040).
## Sobreposição entre profundidades diferentes não é falha (FR-038).
func test_sc026_spacing_between_same_depth_elements() -> void:
	var quadros: int = 600 * 60
	var passo: float = road.scroll_speed * GameConfig.decoration_speed_multiplier / 60.0
	var violacoes: int = 0
	var invasoes: int = 0
	var pulos: int = 0
	var menor_observado: float = INF
	var quadros_com_elementos: int = 0
	var y_anterior: Dictionary = {}

	for i in quadros:
		manager.update(1.0 / 60.0, road)

		if manager.active_count > 0:
			quadros_com_elementos += 1

		var y_agora: Dictionary = {}
		for e in manager.active_elements:
			var id: int = e.get_instance_id()
			y_agora[id] = e.position.y

			if y_anterior.has(id):
				var delta_y: float = e.position.y - float(y_anterior[id])
				# Delta negativo: o objeto saiu do pool e renasceu no mesmo
				# quadro (mesma instância, novo nascimento) — não é pulo.
				if delta_y >= 0.0 and absf(delta_y - passo) > 0.02:
					pulos += 1

			if _invade_area_trafegavel(e):
				invasoes += 1
		y_anterior = y_agora

		var menor: float = _menor_espacamento_mesma_profundidade()
		if menor < GameConfig.decoration_spacing_min:
			violacoes += 1
			menor_observado = minf(menor_observado, menor)

	assert_int(quadros_com_elementos).is_greater(
		quadros / 2
	).override_failure_message("SC-026: corrida longa sem decoração o bastante para verificar")
	assert_int(violacoes).is_zero().override_failure_message(
		"SC-026: %d quadros com separação de mesma profundidade abaixo de %.0f px (menor: %.1f px)"
		% [violacoes, GameConfig.decoration_spacing_min, menor_observado]
	)
	assert_int(invasoes).is_zero().override_failure_message(
		"SC-026: %d quadros com elemento sobre a área trafegável ou na margem de segurança"
		% invasoes
	)
	assert_int(pulos).is_zero().override_failure_message(
		"FR-040: %d elementos perderam quadros de deslocamento na corrida longa" % pulos
	)


## Verdadeiro quando o sprite encosta na área trafegável ou dentro da
## `decoration_safety_margin` (SC-026, SC-021, FR-042).
func _invade_area_trafegavel(e: DecorationElement) -> bool:
	var bounds: Dictionary = road.get_boundaries_for_player_y(e.position.y)
	var esquerda: float = float(bounds.get("left", GameConfig.road_left_boundary))
	var direita: float = float(bounds.get("right", GameConfig.road_right_boundary))
	var meia: float = e.get_dimensao().x * 0.5
	var margem: float = GameConfig.decoration_safety_margin

	return (
		e.position.x + meia > esquerda - margem
		and e.position.x - meia < direita + margem
	)


## Menor separação, na direção de deslocamento, entre elementos da MESMA
## profundidade do mesmo lado. INF quando a profundidade tem menos de 2 pares.
func _menor_espacamento_mesma_profundidade() -> float:
	var por_profundidade: Dictionary = {}
	for e in manager.active_elements:
		var chave: String = "%d:%d" % [e.side, e.depth_index]
		if not por_profundidade.has(chave):
			por_profundidade[chave] = []
		(por_profundidade[chave] as Array).append(e.position.y)

	var menor: float = INF
	for chave in por_profundidade:
		var alturas: Array = por_profundidade[chave]
		for a in alturas.size():
			for b in range(a + 1, alturas.size()):
				menor = minf(menor, absf(float(alturas[a]) - float(alturas[b])))
	return menor
