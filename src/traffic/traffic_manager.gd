class_name TrafficManager
extends Node2D

## Controlador do sistema de trânsito: spawn, seleção de categoria, posicionamento,
## pool reutilizável e reciclagem.
##
## Consome `Road` APENAS por leitura (FR-022, FR-052, I7): nenhum método aqui
## escreve em qualquer propriedade da estrada. Não implementa colisão nesta versão
## (FR-026, constitution v2.0.0 §Trânsito).

signal vehicle_spawned(vehicle: TrafficVehicle)
signal vehicle_recycled(vehicle: TrafficVehicle)

## Mapeamento centralizado id -> categoria, recebido de GameConfig (R4).
var categories: Dictionary[String, TrafficData] = {}

## Conjunto reutilizável, próprio e independente do da decoração (FR-017).
var pool: Array[TrafficVehicle] = []

## Veículos visíveis, para contagem e verificação de espaçamento.
var active_vehicles: Array[TrafficVehicle] = []

## Catálogo de índices de assets já medidos, por categoria — evita remedir por recycle.
var _indices_por_categoria: Dictionary[String, Array] = {}

## Deslocamento desejado (FR-007) e posição final do quadro (FR-019/SC-006) de
## cada veículo ativo. Reutilizados quadro a quadro.
var _dy_desejado: Array[float] = []
var _y_futuro: Array[float] = []

## Índices dos veículos que descem e que sobem, ordenados com o líder primeiro.
var _ordem_desc: Array[int] = []
var _ordem_asc: Array[int] = []

## Tempo acumulado até o próximo spawn (FR-004).
var _cronometro_spawn: float = 0.0

## Habilitação do spawn (FR-024).
var _habilitado: bool = true

const VIEWPORT_HEIGHT: float = 480.0

## Folga numérica somada ao espaçamento mínimo (FR-019, SC-006).
##
## As posições acumulam somas em ponto flutuante: sem essa folga, um par
## mantido exatamente em `traffic_min_spacing` oscila em torno de 69,999 px e
## conta como violação em alguns quadros. Um centésimo de pixel é imperceptível
## e elimina o ruído sem afetar a leitura do espaçamento.
const FOLGA_ESPACAMENTO: float = 0.01


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Recebe as categorias de GameConfig (contrato §4).
## Cada valor pode ser a entrada crua de GameConfig (um Dictionary) ou um
## TrafficData já montado — o gameplay_manager passa o Dictionary, os testes
## unitários passam o Resource para não depender das pastas de asset.
func setup(p_categories: Dictionary) -> void:
	categories.clear()
	for id in p_categories:
		# Sem tipo explícito: a checagem abaixo precisa ser de runtime, senão o
		# analisador descarta o ramo `is TrafficData` como impossível.
		var entrada = p_categories[id]
		var data: TrafficData
		if entrada is TrafficData:
			data = entrada
		else:
			data = TrafficData.new(entrada)
		# FR-011: mede a largura real da textura aqui, não no primeiro `activate`.
		# `_tentar_spawn` calcula a faixa livre na altura de criação com `size`
		# (I2/FR-014) e a medição dentro do `activate` chegaria tarde demais.
		data.garantir_size()
		categories[id] = data
	_habilitado = GameConfig.traffic_enabled


func _process(_delta: float) -> void:
	# O atualização acontece em update(), chamada pelo gameplay_manager na ordem
	# definida por FR-055. Este override existe apenas para não processar fora de hora.
	pass


## Atualiza spawn, movimento, reposicionamento e reciclagem (contrato §4).
func update(delta: float, road: Road) -> void:
	if road == null:
		return

	var velocidade: float = road.scroll_speed

	_recolher_inativos()

	# FR-007 / FR-016 / T015: o movimento dos veículos ativos NÃO é suprimido pela
	# velocidade zero. Com o jogador parado o veículo sobe com a própria
	# velocidade, continua sendo reposicionado e é reciclado ao sair pelo topo.
	# Estrada parada não pode congelar o trânsito (FR-016).
	_mover_ativos(delta, velocidade, road)

	# SC-022: com a estrada parada nenhum veículo NOVO é criado — é o birth que
	# some, não o movimento nem a reciclagem.
	if velocidade <= 0.0 or not _habilitado:
		return

	_cronometro_spawn += delta
	if _cronometro_spawn >= GameConfig.traffic_spawn_interval:
		_cronometro_spawn = 0.0
		_tentar_spawn(road)


## Habilita ou desabilita o spawn (FR-024, T041).
## Com `false`, nenhum veículo novo é criado e os existentes seguem movimento normal.
func set_enabled(enabled: bool) -> void:
	_habilitado = enabled


## Snapshot dos seis atributos de FR-002 — tipo, posição, velocidade, direção,
## faixa e estado — acrescidos da `occupied_area` do SPEC-005 (FR-025).
## Construído SOB DEMANDA e nunca dentro de update(), para não introduzir
## alocação por quadro (R9).
func get_vehicles_data() -> Array[Dictionary]:
	var dados: Array[Dictionary] = []
	for v in active_vehicles:
		dados.append({
			"id": v.get_category_id(),
			"position": v.position,
			"speed": v.get_speed(),
			"direction": v.get_direction(),
			"lane": v.lane_position,
			"state": v.state,
			"occupied_area": v.get_occupied_area(),
		})
	return dados


## Quantidade atual de veículos ativos (I1).
var active_count: int:
	get:
		return active_vehicles.size()


## Tamanho atual do conjunto reutilizável.
var pool_size: int:
	get:
		return pool.size()


## Cópia defensiva dos veículos ativos.
var active_vehicles_snapshot: Array[TrafficVehicle]:
	get:
		return active_vehicles.duplicate()


# ---------------------------------------------------------------------------
# Spawn
# ---------------------------------------------------------------------------

func _tentar_spawn(road: Road) -> void:
	# I1 / FR-005: nunca acima do limite configurado.
	if active_vehicles.size() >= GameConfig.traffic_max_vehicles:
		return

	var categoria: TrafficData = _sortear_categoria()
	if categoria == null:
		return

	# I3: nasce acima da área visível, com folga igual à própria altura.
	var y: float = -categoria.size.y - GameConfig.traffic_spawn_distance

	# FR-014 / I2: valida a faixa livre NA ALTURA DE CRIAÇÃO, não na do jogador.
	var bounds: Dictionary = road.get_boundaries_for_player_y(y)
	var min_x: float = _menor_x_livre(categoria, bounds)
	var max_x: float = _maior_x_livre(categoria, bounds)
	if max_x - min_x <= 0.0:
		return

	# FR-019: espaçamento longitudinal verificado antes de criar.
	if _espaco_longo_insuficiente(y):
		return

	var veiculo: TrafficVehicle = _obter_do_pool()
	var lane: float = min_x + (max_x - min_x) * randf()
	veiculo.activate(categoria, lane, y)
	veiculo.position.x = lane
	veiculo.previous_right_boundary = bounds.get("right", 0.0)
	# O nó já tem este manager como pai: veio do pool, ou foi criado e anexado em
	# `_obter_do_pool`. Anexar de novo aqui causaria erro de reparenting.
	if veiculo.get_parent() != self:
		add_child(veiculo)

	active_vehicles.append(veiculo)
	vehicle_spawned.emit(veiculo)


## Sorteio ponderado pela frequência (FR-010, FR-023, T017).
## Categorias com `frequency == 0.0` permanecem configuráveis mas nunca são
## selecionadas.
func _sortear_categoria() -> TrafficData:
	var ids_sorteaveis: Array[String] = []
	var pesos: Array[float] = []
	var total: float = 0.0

	for id in categories:
		var categoria: TrafficData = categories[id]
		if not categoria.is_spawnable():
			continue
		ids_sorteaveis.append(id)
		pesos.append(categoria.frequency)
		total += categoria.frequency

	if ids_sorteaveis.is_empty() or total <= 0.0:
		return null

	var alvo: float = randf() * total
	var acumulado: float = 0.0
	for i in ids_sorteaveis.size():
		acumulado += pesos[i]
		if alvo <= acumulado:
			return categories[ids_sorteaveis[i]]

	return categories[ids_sorteaveis[ids_sorteaveis.size() - 1]]


## Menor `x` válido para o centro de um veículo da categoria, na altura `y`.
## Desconta a meia-largura real do asset, então o veículo nasce inteiramente
## dentro da área trafegável (FR-014, I2).
func _menor_x_livre(categoria: TrafficData, bounds: Dictionary) -> float:
	var esquerda: float = bounds.get("left", GameConfig.road_left_boundary)
	return esquerda + categoria.size.x * 0.5


## Maior `x` válido para o centro de um veículo da categoria, na altura `y`.
func _maior_x_livre(categoria: TrafficData, bounds: Dictionary) -> float:
	var direita: float = bounds.get("right", GameConfig.road_right_boundary)
	return direita - categoria.size.x * 0.5


## Verdadeiro quando não há espaço longitudinal para mais um veículo na altura
## `y` de criação (FR-019).
##
## Não bloqueia sobreposição lateral — apenas o espaçamento longitudinal mínimo,
## conforme FR-019 / SC-006.
func _espaco_longo_insuficiente(y: float) -> bool:
	var minimo: float = GameConfig.traffic_min_spacing + FOLGA_ESPACAMENTO
	for v in active_vehicles:
		if absf(v.position.y - y) < minimo:
			return true
	return false


func _obter_do_pool() -> TrafficVehicle:
	for v in pool:
		if not v.is_active():
			return v

	# I6 / FR-018: cresce sob demanda em vez de recusar criação.
	var novo := TrafficVehicle.new()
	novo.name = "TrafficVehicle"
	add_child(novo)
	pool.append(novo)
	return novo


# ---------------------------------------------------------------------------
# Movimento e reciclagem
# ---------------------------------------------------------------------------

func _mover_ativos(delta: float, velocidade: float, road: Road) -> void:
	var vista: Rect2 = _retangulo_de_visao()
	var n: int = active_vehicles.size()
	if n == 0:
		return

	_dy_desejado.resize(n)
	_y_futuro.resize(n)
	for i in n:
		var v: TrafficVehicle = active_vehicles[i]
		# FR-007: deslocamento aparente desejado = diferença para a estrada.
		var dy: float = -(v.get_speed() - velocidade) * delta
		_dy_desejado[i] = dy
		# Posição que o veículo vai ocupar ao fim do quadro. O líder ainda não
		# movido é previsto pelo deslocamento desejado; o que já foi movido vale
		# pela posição atual.
		_y_futuro[i] = v.position.y + dy

	# FR-019 / SC-006: o líder (à frente no sentido do próprio movimento) é
	# movido primeiro, para que o seguidor limite o fechamento com a posição
	# final já alcançada pelo líder.
	_ordem_desc.clear()
	_ordem_asc.clear()
	for i in n:
		if _dy_desejado[i] >= 0.0:
			_ordem_desc.append(i)
		else:
			_ordem_asc.append(i)
	_ordem_desc.sort_custom(_cmp_maior_y)
	_ordem_asc.sort_custom(_cmp_menor_y)

	for i in _ordem_desc:
		_mover_com_limite(i, delta, velocidade, road, INF)
	for i in _ordem_asc:
		_mover_com_limite(i, delta, velocidade, road, -INF)

	# Reciclagem em iteração reversa: remover durante a passagem faria o
	# veículo seguinte perder um quadro de deslocamento (FR-019, SC-006).
	for i in range(n - 1, -1, -1):
		var v: TrafficVehicle = active_vehicles[i]
		if _saiu_da_vista(v, vista):
			_desativar(v)


## Ordena o índice do veículo de maior `y` primeiro (FR-019).
func _cmp_maior_y(a: int, b: int) -> bool:
	return active_vehicles[a].position.y > active_vehicles[b].position.y


## Ordena o índice do veículo de menor `y` primeiro (FR-019).
func _cmp_menor_y(a: int, b: int) -> bool:
	return active_vehicles[a].position.y < active_vehicles[b].position.y


## Índice do veículo mais próximo na direção `para_baixo` do movimento — o
## líder que impõe o espaçamento longitudinal mínimo (FR-019, SC-006).
func _lider_mais_proximo(i: int, y0: float, para_baixo: bool) -> int:
	var melhor: int = -1
	var menor_gap: float = INF
	for j in active_vehicles.size():
		if j == i:
			continue
		var gap: float = active_vehicles[j].position.y - y0
		if para_baixo:
			if gap > 0.0 and gap < menor_gap:
				menor_gap = gap
				melhor = j
		elif gap < 0.0 and -gap < menor_gap:
			menor_gap = -gap
			melhor = j
	return melhor


## Move o veículo `i` limitando o fechamento para nunca invadir
## `traffic_min_spacing` no líder (FR-019, SC-006).
##
## O limite é um teto para quem desce (chegar no máximo `traffic_min_spacing`
## abaixo da posição final do líder) e um piso para quem sobe; `padrao` é o
## valor usado quando não há líder na direção do movimento. O próprio veículo
## ainda recusa andar para trás (FR-006), então um par apertado para junto em
## `traffic_min_spacing` em vez de atravessar.
func _mover_com_limite(i: int, delta: float, velocidade: float, road: Road, padrao: float) -> void:
	var v: TrafficVehicle = active_vehicles[i]
	var y0: float = v.position.y
	var dy: float = _dy_desejado[i]
	var limite: float = padrao

	if dy > 0.0:
		var lider: int = _lider_mais_proximo(i, y0, true)
		if lider >= 0:
			limite = (
				_y_futuro[lider] - y0
				- GameConfig.traffic_min_spacing - FOLGA_ESPACAMENTO
			)
	elif dy < 0.0:
		var lider: int = _lider_mais_proximo(i, y0, false)
		if lider >= 0:
			limite = (
				GameConfig.traffic_min_spacing + FOLGA_ESPACAMENTO
				- (y0 - _y_futuro[lider])
			)

	var bounds: Dictionary = road.get_boundaries_for_player_y(y0)
	v.update_scroll(delta, velocidade, bounds, limite)
	_y_futuro[i] = v.position.y


## Verdadeiro quando nenhum pixel do veículo está na área visível, reciclando-o
## em seguida (I5, FR-016, FR-043).
##
## `TrafficVehicle.ja_visto` é o que separa "veio de cima e ainda não entrou"
## (FR-013) de "entrou na tela e saiu pelo topo" (FR-016). Sem essa distinção,
## todo veículo nasceria reciclado no quadro seguinte ao do birth.
func _saiu_da_vista(v: TrafficVehicle, vista: Rect2) -> bool:
	var dimensoes: Vector2 = v.category.size if v.category != null else Vector2.ZERO
	var meia: float = dimensoes.y * 0.5
	var topo: float = v.position.y - meia
	var base: float = v.position.y + meia

	# Lateral: a faixa trafegável impede na prática, mas a regra é "qualquer
	# borda" (FR-043).
	var meia_x: float = dimensoes.x * 0.5
	if v.position.x + meia_x < vista.position.x or v.position.x - meia_x > vista.end.x:
		return true

	if base >= vista.position.y and topo <= vista.end.y:
		# Há pixel visível: o veículo está na tela (FR-007).
		v.ja_visto = true
		return false

	if not v.ja_visto:
		# Nasceu acima do topo (FR-013). Só conta como saída quando está se
		# afastando da área visível — ou seja, subiu acima do ponto de criação.
		# Nesse caminho ele jamais entraria na tela, e continuar aqui acumularia
		# veículos no pool e bloquearia novos births por espaçamento (FR-019).
		return v.position.y < v.y_nascimento or base > vista.end.y

	return true


## Área visível em coordenadas de mundo. Sem câmera na cena, coincide com o
## retângulo do viewport: y de 0 (topo) a `size.y` (base).
func _retangulo_de_visao() -> Rect2:
	if get_viewport() == null:
		return Rect2(0, 0, 640, VIEWPORT_HEIGHT)
	return get_viewport_rect()


func _desativar(v: TrafficVehicle) -> void:
	var indice: int = active_vehicles.find(v)
	if indice == -1:
		return
	active_vehicles.remove_at(indice)
	v.deactivate()
	vehicle_recycled.emit(v)


## Recolhe do array ativo os veículos já desativados por outros caminhos.
## Varredura sem alocação: reescreve no lugar em vez de filtrar (R9).
func _recolher_inativos() -> void:
	var escrita: int = 0
	for leitura in active_vehicles.size():
		var v: TrafficVehicle = active_vehicles[leitura]
		if v.is_active():
			active_vehicles[escrita] = v
			escrita += 1
		else:
			vehicle_recycled.emit(v)

	if escrita < active_vehicles.size():
		active_vehicles.resize(escrita)