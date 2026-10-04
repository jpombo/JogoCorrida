class_name DecorationManager
extends Node2D

## Controlador da decoração lateral: ambiente -> biblioteca, distribuição nos dois
## lados em múltiplas profundidades, deslocamento derivado da estrada e pool próprio.
##
## Consome `Road` e `EnvironmentManager` APENAS por leitura (FR-052, D9).
## NÃO implementa colisão (FR-049). O pool é independente do do trânsito (FR-044, D10).

signal environment_changed(new_id: String, old_id: String)
signal element_recycled(element: DecorationElement)
signal library_empty(environment_id: String)

enum Side { LEFT, RIGHT }

## Ciclos externos, iterações internas e disponibilidade mínima do ajuste de
## pesos de sorteio (ver _compensar_pesos).
const _COMP_CICLOS: int = 10
const _COMP_INTERNO: int = 15
const _COMP_DISP_MIN: float = 0.02

## Mapeamento ambiente -> biblioteca, recebido de GameConfig (R4).
## Godot não aceita aninhamento de coleções tipadas (`Array[T]` dentro de
## `Dictionary[K, V]`); o tipo do valor fica por conta de quem atribui.
var libraries: Dictionary[String, Array] = {}

## Ambiente vigente (FR-028).
var current_environment_id: String = ""

## Conjunto reutilizável próprio, independente do de trânsito (FR-044).
var pool: Array[DecorationElement] = []

## Elementos visíveis.
var active_elements: Array[DecorationElement] = []

## Contadores de repetição por lado, somando todas as profundidades (D8, T028).
var last_repeat_by_side: Dictionary = {}

## Último asset usado por lado, para a regra de não repetição imediata (D6).
var _ultimos_por_lado: Dictionary = {}

## Cronômetro até o próximo birth, por lado.
var _cronometro_birth: Dictionary = {Side.LEFT: 0.0, Side.RIGHT: 0.0}

## Habilitação da decoração (FR-056).
var _habilitado: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Recebe as bibliotecas de GameConfig (contrato §5).
func setup(p_libraries: Dictionary) -> void:
	libraries.clear()
	for ambiente in p_libraries:
		libraries[ambiente] = _montar_biblioteca(ambiente, p_libraries[ambiente])


## Troca a biblioteca em uso (FR-031, D1, US6).
## Elementos do ambiente anterior são desativados e nenhum permanece em tela (SC-008).
func set_environment(id: String) -> void:
	var antiga: String = current_environment_id
	if id == antiga:
		return

	if not libraries.has(id):
		push_warning("DecorationManager: biblioteca desconhecida '%s', mantido '%s'" % [id, antiga])
		library_empty.emit(id)
		return

	_desativar_todos()

	current_environment_id = id
	last_repeat_by_side.clear()
	_cronometro_birth[Side.LEFT] = 0.0
	_cronometro_birth[Side.RIGHT] = 0.0

	if libraries[id].is_empty():
		library_empty.emit(id)

	environment_changed.emit(id, antiga)


## Atualiza deslocamento, reposicionamento e reciclagem (contrato §5).
func update(delta: float, road: Road) -> void:
	if road == null:
		return

	var velocidade: float = road.scroll_speed
	var vista: Rect2 = _retangulo_de_visao()

	# D5 / SC-022: com o jogador parado nada se desloca, nada nasce e nada morre.
	if velocidade <= 0.0:
		return

	# Percorre de trás para frente: `_desativar` remove do array e uma iteração
	# em ordem crescente pularia o elemento seguinte, fazendo-o perder um quadro
	# de deslocamento e desalinhar o espaçamento longitudinal (FR-038, SC-026).
	for i in range(active_elements.size() - 1, -1, -1):
		var e: DecorationElement = active_elements[i]
		var bounds: Dictionary = road.get_boundaries_for_player_y(e.position.y)
		e.update_scroll(delta, velocidade, bounds)
		if e.is_fully_outside(vista):
			_desativar(e)

	if not _habilitado:
		return

	_tentar_birth(delta, road)


## Habilita ou desabilita a decoração (FR-056, T041).
## Com `false`, os elementos existentes deixam de ser exibidos, sem afetar a
## estrada nem o jogador.
func set_enabled(enabled: bool) -> void:
	_habilitado = enabled
	if not enabled:
		_desativar_todos()


## Snapshot de diagnóstico; não é requisito desta versão (ver contrato §9).
func get_repeat_state(side: int) -> int:
	return int(last_repeat_by_side.get(side, 0))


## Quantidade atual de elementos ativos.
var active_count: int:
	get:
		return active_elements.size()


## Tamanho atual do conjunto reutilizável.
var pool_size: int:
	get:
		return pool.size()


# ---------------------------------------------------------------------------
# Biblioteca
# ---------------------------------------------------------------------------

## Converte as entradas cruas de GameConfig em DecorationData (FR-029, R3).
## `repeatable` vem do valor declarado — nunca do nome do arquivo.
func _montar_biblioteca(ambiente: String, entradas: Array) -> Array[DecorationData]:
	var resultado: Array[DecorationData] = []
	var pasta: String = String(GameConfig.DECORATION_PATHS.get(ambiente, ""))

	for entrada in entradas:
		var dados: Dictionary = entrada if entrada is Dictionary else {}
		var nome: String = String(dados.get("asset", ""))
		if nome.is_empty():
			continue
		var data: DecorationData = DecorationData.from_entry(
			nome, pasta, bool(dados.get("repeatable", false)), float(dados.get("weight", 100.0))
		)
		# I2 / FR-042: mede já aqui, para o primeiro nascimento nascer com a
		# altura e a meia-largura reais em vez de `size == ZERO`.
		data.garantir_size()
		resultado.append(data)

	_compensar_pesos(resultado)

	return resultado


# ---------------------------------------------------------------------------
# Peso de sorteio
# ---------------------------------------------------------------------------

## Corrige o peso de sorteio para que a frequência OBSERVADA de cada elemento
## se aproxime do percentual declarado em `DecorationData.weight` (FR-036,
## FR-037). Roda uma vez por biblioteca, no `setup`.
##
## D6 e D7 enviesam a distribuição: um não repetível sai da disputa logo após
## aparecer, e uma árvore sai da disputa ao chegar em
## `decoration_tree_repeat_limit` seguidas — nos dois casos a fatia do ausente
## migra para quem ficou elegível. O ajuste resolve numericamente os pesos que
## neutralizam esse viés, alternando duas correções fixas (inversa: percentual
## declarado -> pesos; direta: pesos -> frequência prevista) e uma estimativa da
## disponibilidade de repetição `1 - p^limite`.
##
## `weight` não é alterado: continua sendo a meta declarada em configuração, a
## que o validador confere. Só `peso_sorteio` é recalculado.
##
## Limite conhecido (SC-014): em biblioteca com uma única árvore repetível, D7
## impõe teto de `limite / (limite + 1)` ≈ 90,9% para a frequência observada.
## Em ICE a árvore declarada com 96% chega perto desse teto, não dos 96%.
func _compensar_pesos(dados: Array[DecorationData]) -> void:
	var n: int = dados.size()
	if n <= 1:
		return

	var alvo := PackedFloat64Array()
	var soma: float = 0.0
	for data in dados:
		var w: float = maxf(0.0, data.weight)
		alvo.append(w)
		soma += w
	if soma <= 0.0:
		return

	var pesos := PackedFloat64Array()
	var disp := PackedFloat64Array()
	var rep := PackedByteArray()
	for i in n:
		alvo[i] = alvo[i] / soma
		pesos.append(alvo[i])
		disp.append(1.0)
		rep.append(1 if dados[i].repeatable else 0)

	var limite: int = maxi(1, GameConfig.decoration_tree_repeat_limit)
	for _ciclo in _COMP_CICLOS:
		for _passo in _COMP_INTERNO:
			pesos = _inverter_pesos(alvo, pesos, disp, rep)
		var previsto := alvo.duplicate()
		for _passo in _COMP_INTERNO:
			previsto = _passo_frequencia(previsto, pesos, disp, rep)
		for i in n:
			if rep[i] == 1:
				disp[i] = maxf(_COMP_DISP_MIN, 1.0 - pow(previsto[i], float(limite)))

	for i in n:
		dados[i].peso_sorteio = pesos[i] * 100.0


## Contribuição de cada elemento na disputa normalizada: `p_j / (Q - q_j)` para
## não repetível (sai da disputa quando é o anterior) e `p_j / Q` para
## repetível (nunca é banido por D6). Numeradores vêm de `p`, denominadores dos
## pesos correntes.
func _termos(
	p: PackedFloat64Array,
	pesos: PackedFloat64Array,
	rep: PackedByteArray
) -> PackedFloat64Array:
	var q: float = 0.0
	for peso in pesos:
		q += peso

	var termos := PackedFloat64Array()
	for j in p.size():
		if rep[j] == 1:
			termos.append(p[j] / q if q > 1e-12 else 0.0)
		else:
			var den: float = q - pesos[j]
			termos.append(p[j] / den if den > 1e-9 else 0.0)
	return termos


## Passo inverso: pesos que, com a disponibilidade corrente, dão a cada
## elemento a fatia declarada. A soma é normalizada em 1.0 (só a proporção
## importa no sorteio).
func _inverter_pesos(
	alvo: PackedFloat64Array,
	pesos: PackedFloat64Array,
	disp: PackedFloat64Array,
	rep: PackedByteArray
) -> PackedFloat64Array:
	var termos := _termos(alvo, pesos, rep)
	var total: float = 0.0
	for t in termos:
		total += t

	var soma: float = 0.0
	var novo := PackedFloat64Array()
	for i in alvo.size():
		# Repetível entra no total inteiro (não é banido por D6); não repetível
		# perde a própria parcela, que só existe quando ele é o anterior.
		var elegivel: float = total - termos[i] if rep[i] == 0 else total
		var divisor: float = disp[i] * elegivel
		var peso: float = alvo[i] / divisor if divisor > 1e-12 else alvo[i]
		novo.append(peso)
		soma += peso

	if soma <= 0.0:
		return pesos
	for i in novo.size():
		novo[i] = novo[i] / soma
	return novo


## Passo direto: frequência prevista para os pesos correntes, já aplicando a
## disponibilidade de repetição. Relaxado várias vezes, converge para a
## distribuição de estado estacionário do sorteio.
func _passo_frequencia(
	previsto: PackedFloat64Array,
	pesos: PackedFloat64Array,
	disp: PackedFloat64Array,
	rep: PackedByteArray
) -> PackedFloat64Array:
	var termos := _termos(previsto, pesos, rep)
	var total: float = 0.0
	for t in termos:
		total += t

	var soma: float = 0.0
	var novo := PackedFloat64Array()
	for i in previsto.size():
		var elegivel: float = total - termos[i] if rep[i] == 0 else total
		var frequencia: float = disp[i] * pesos[i] * elegivel
		novo.append(frequencia)
		soma += frequencia

	if soma <= 0.0:
		return previsto
	for i in novo.size():
		novo[i] = novo[i] / soma
	return novo


## Assets utilizáveis da biblioteca vigente (asset ausente é ignorado, não fatal).
func _biblioteca_vigente() -> Array[DecorationData]:
	if not libraries.has(current_environment_id):
		return []
	var utilizaveis: Array[DecorationData] = []
	for data in libraries[current_environment_id]:
		if data.is_usable():
			utilizaveis.append(data)
	return utilizaveis


# ---------------------------------------------------------------------------
# Distribuição
# ---------------------------------------------------------------------------

func _tentar_birth(delta: float, road: Road) -> void:
	var biblioteca: Array[DecorationData] = _biblioteca_vigente()
	if biblioteca.is_empty():
		return

	for lado in [Side.LEFT, Side.RIGHT]:
		_cronometro_birth[lado] = float(_cronometro_birth.get(lado, 0.0)) + delta
		var intervalo: float = _intervalo(road.scroll_speed)
		if float(_cronometro_birth[lado]) < intervalo:
			continue
		_cronometro_birth[lado] = 0.0
		_criar_elemento(lado, biblioteca, road)


## Intervalo entre births, derivado de density (FR-037) e do espaçamento (FR-038).
##
## `decoration_spacing_min/max` é um espaçamento LONGITUDINAL em pixels, não em
## segundos: para convertê-lo em tempo é preciso dividir pela velocidade real de
## deslocamento do elemento, que é `road.scroll_speed * decoration_speed_multiplier`
## (FR-039). Sem essa divisão o intervalo saía em dezenas de segundos e quase
## nada nascia.
func _intervalo(velocidade: float) -> float:
	var base: float = GameConfig.decoration_spacing_min
	var amplitude: float = maxf(
		0.0, GameConfig.decoration_spacing_max - GameConfig.decoration_spacing_min
	)
	var distancia: float = base + randf() * amplitude
	# `density` é um programador de distância média: valores maiores aproximam
	# os elementos, valores menores os afastam.
	var divisor: float = maxf(0.1, GameConfig.decoration_density)
	var deslocamento: float = maxf(
		1.0, velocidade * maxf(0.1, GameConfig.decoration_speed_multiplier)
	)
	return maxf(0.1, distancia / divisor / deslocamento)


## Cria um elemento numa lateral, respeitando profundidade, margem de segurança,
## repetição e espaçamento longitudinal (FR-028 a FR-038, FR-042, FR-046, FR-050).
func _criar_elemento(lado: int, biblioteca: Array[DecorationData], road: Road) -> void:
	var data: DecorationData = _escolher_asset(biblioteca, lado)
	if data == null:
		return

	# D3 / FR-041: nasce acima da área visível, já fora da estrada.
	var y: float = -data.size.y - 40.0

	var profundidade: int = _escolher_profundidade(data)
	var lane: float = _posicao_lateral(lado, profundidade, data, road, y)
	if lane == INF:
		# Nenhuma profundidade comporta o asset — tenta a mais distante (caso de borda).
		profundidade = GameConfig.decoration_depth_count - 1
		lane = _posicao_lateral(lado, profundidade, data, road, y)
		if lane == INF:
			return

	# FR-038 / SC-026: sem espaço longitudinal na direção de deslocamento, o
	# nascimento é suprimido — nascer sobreposto ao anterior da mesma
	# profundidade quebraria decoration_spacing_min.
	if _espaco_longo_insuficiente(lado, profundidade, y):
		return

	var elemento: DecorationElement = _obter_do_pool()
	elemento.activate(data, lado, profundidade, y)
	elemento.position.x = lane
	elemento.position.y = y
	# O nó já tem este manager como pai: veio do pool, ou foi criado e anexado em
	# `_obter_do_pool`. Anexar de novo aqui causaria erro de reparenting.
	if elemento.get_parent() != self:
		add_child(elemento)

	active_elements.append(elemento)


## FR-038 / SC-026 — verdadeiro quando não cabe mais um elemento da MESMA
## profundidade do lado indicado na altura `y` de criação.
##
## A separação medida é apenas na direção de deslocamento: sobreposição lateral
## entre profundidades é permitida e desejada (FR-038). Nascer sobreposto ao
## anterior violaria `decoration_spacing_min`, então o nascimento é suprimido e
## o tenta de novo no intervalo seguinte, quando o par já se afastou.
func _espaco_longo_insuficiente(lado: int, profundidade: int, y: float) -> bool:
	for e in active_elements:
		if e.side != lado or e.depth_index != profundidade:
			continue
		if absf(e.position.y - y) < GameConfig.decoration_spacing_min:
			return true
	return false


## Escolhe o asset respeitando os contadores de repetição do lado (D6, D7, D8, T028)
## e os percentuais de apresentação declarados na biblioteca (FR-036, FR-037).
##
## Os contadores são POR LADO e somam todas as profundidades: um asset repetível
## pode aparecer até `decoration_tree_repeat_limit` vezes consecutivas no mesmo
## lado, e um não repetível nunca sai duas vezes seguidas enquanto houver alternativa.
##
## Entre os candidatos elegíveis a escolha é PONDERADA por `data.peso_sorteio`,
## o peso interno já compensado por `_compensar_pesos` para que a frequência
## observada chegue perto do percentual de apresentação declarado em
## `data.weight` (FR-036, FR-037). Os pesos são somados só dos elegíveis, de
## modo que a regra de repetição nunca anula um elemento: se um sai da lista por
## D6/D7, a fatia dele é redistribuída entre os demais naquele nascimento, e a
## distribuição de longo prazo volta ao percentual declarado assim que o
## elegível volta a entrar.
func _escolher_asset(biblioteca: Array[DecorationData], lado: int) -> DecorationData:
	var contador: int = int(last_repeat_by_side.get(lado, 0))
	var limite: int = GameConfig.decoration_tree_repeat_limit
	var ultimo: DecorationData = _ultimos_por_lado.get(lado, null)

	var candidatos: Array[DecorationData] = []
	for data in biblioteca:
		if data.repeatable:
			# Repetível: liberado enquanto não atingir o limite.
			if contador < limite:
				candidatos.append(data)
		elif data != ultimo:
			# Não repetível: só entra se não for o último usado neste lado.
			candidatos.append(data)

	if candidatos.is_empty():
		# Sem alternativa: repete-se o último asset, cuja sequência não é falha
		# (caso de borda "biblioteca com um único elemento").
		return ultimo if ultimo != null else biblioteca[0]

	var escolhido: DecorationData = _sortear_ponderado(candidatos)

	# Atualiza o contador: incrementa se repete, senão reinicia em 1.
	last_repeat_by_side[lado] = contador + 1 if escolhido == ultimo else 1
	_ultimos_por_lado[lado] = escolhido
	return escolhido


## Sorteio ponderado por `peso_sorteio` (peso já compensado para D6/D7),
## normalizado sobre os candidatos informados.
## Com peso total zero (ou só um candidato) a escolha é uniforme.
func _sortear_ponderado(candidatos: Array[DecorationData]) -> DecorationData:
	if candidatos.size() == 1:
		return candidatos[0]

	var total: float = 0.0
	for data in candidatos:
		total += maxf(0.0, data.peso_sorteio)

	if total <= 0.0:
		return candidatos[randi() % candidatos.size()]

	var sorteio: float = randf() * total
	var acumulado: float = 0.0
	for data in candidatos:
		acumulado += maxf(0.0, data.peso_sorteio)
		if sorteio < acumulado:
			return data

	# Inalcançável com total > 0; mantém o retorno tipado para o editor.
	return candidatos[candidatos.size() - 1]


func _ultimo_do_lado(lado: int) -> DecorationData:
	return _ultimos_por_lado.get(lado, null)


## Escolhe uma profundidade que comporte o asset (FR-034).
## Elemento maior que a profundidade disponível vai para a mais distante que o
## comporte — resolvido em _criar_elemento.
func _escolher_profundidade(data: DecorationData) -> int:
	var total: int = maxi(1, GameConfig.decoration_depth_count)
	var tamanho: float = GameConfig.decoration_depth_spacing
	var necessaria: int = maxi(1, ceili(data.size.y / maxf(1.0, tamanho)))

	var inicio: int = 0
	if necessaria < total:
		inicio = randi() % (total - necessaria + 1)

	return clampi(inicio, 0, total - 1)


## Posição horizontal do centro do elemento, já fora da área trafegável e da
## margem de segurança (FR-033, D2, SC-021). Devolve INF se não couber.
func _posicao_lateral(lado: int, profundidade: int, data: DecorationData, road: Road, y: float) -> float:
	var bounds: Dictionary = road.get_boundaries_for_player_y(y)
	var esquerda: float = bounds.get("left", GameConfig.road_left_boundary)
	var direita: float = bounds.get("right", GameConfig.road_right_boundary)
	var margem: float = GameConfig.decoration_safety_margin
	var meia: float = data.size.x * 0.5

	# Profundidade 0 é a mais próxima da estrada; cada uma se afasta em
	# decoration_depth_spacing pixels (FR-034).
	var afastamento: float = margem + meia + float(profundidade) * GameConfig.decoration_depth_spacing

	if lado == Side.LEFT:
		var x: float = esquerda - afastamento
		# Precisa caber na lateral sem sair da viewport.
		if x - meia < 0.0:
			return INF
		return x

	var x_d: float = direita + afastamento
	if x_d + meia > GameConfig.road_left_boundary * 2.0 + 176.0:
		return INF
	return x_d


# ---------------------------------------------------------------------------
# Pool e reciclagem
# ---------------------------------------------------------------------------

func _obter_do_pool() -> DecorationElement:
	for e in pool:
		if not e.is_active():
			return e

	var novo := DecorationElement.new()
	novo.name = "DecorationElement"
	add_child(novo)
	pool.append(novo)
	return novo


func _desativar(e: DecorationElement) -> void:
	var indice: int = active_elements.find(e)
	if indice == -1:
		return
	active_elements.remove_at(indice)
	e.deactivate()
	element_recycled.emit(e)


func _desativar_todos() -> void:
	for e in active_elements:
		e.deactivate()
	active_elements.clear()


func _retangulo_de_visao() -> Rect2:
	if get_viewport() == null:
		return Rect2(0, 0, 640, 480)
	return get_viewport_rect()