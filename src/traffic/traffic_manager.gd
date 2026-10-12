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

## Validador de nascimento do SPEC-006 (FR-028, contrato
## spawn_validation.md). `null` preserva o caminho legado do SPEC-004
## (faixa única da velocidade, nenhuma consulta) — é o que os testes de
## SPEC-001–005 enxergam, garantindo a regressão SC-016.
var validador: NpcCollisionSystem = null

## Candidato adiado para o quadro seguinte (FR-029, Clarificação Q3):
## `{"categoria": TrafficData}`. Revalidado a cada quadro em `update()` com
## as posições atualizadas até nascer; nunca descartado até o próximo
## intervalo de spawn — a reposição abaixo de `traffic_min_visible` fica
## intacta (FR-063, SC-010).
var _spawn_pendente: Dictionary = {}

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

	# Densidade alvo (ajuste 3/4): a meta é manter ao menos `traffic_min_visible`
	# NPCs NA ESTRADA (na tela ou a poucos pixels acima dela, já em aproximação
	# — a faixa `-MARGEM_PISTA..base` conta os que o jogador verá em ~2 s);
	# o teto da dificuldade limita os ATIVOS (visíveis + a caminho), porque
	# todo ativo acaba entrando na tela — só assim o máximo de visíveis é
	# garantido. Abaixo do mínimo a reposição é imediata (um por quadro,
	# nascendo logo acima da tela — esteira contínua, sem lote nem seca);
	# no fluxo normal vale o intervalo configurado.
	var na_pista: int = _contar_na_pista()
	var minimo: int = GameConfig.traffic_min_visible
	var maximo: int = _maximo_visivel_atual()

	if active_vehicles.size() >= maximo:
		_cronometro_spawn = 0.0
	elif not _spawn_pendente.is_empty():
		# FR-029 / Clarificação Q3: o adiado revalida A CADA QUADRO, com o y
		# e as posições recomputados — o cronômetro fica intacto enquanto
		# ele espera (adiamento por quadro, nunca até o próximo intervalo).
		_tentar_spawn(road, na_pista <= minimo, _spawn_pendente.get("categoria") as TrafficData)
	elif na_pista <= minimo:
		_cronometro_spawn = 0.0
		_tentar_spawn(road, true)
	else:
		_cronometro_spawn += delta
		if _cronometro_spawn >= GameConfig.traffic_spawn_interval:
			_cronometro_spawn = 0.0
			_tentar_spawn(road, false)


## O candidato adiado em `update()`, ou dicionário vazio quando não há
## pendente — superfície de introspecção para os testes de FR-029/SC-010.
func spawn_pendente() -> Dictionary:
	return _spawn_pendente


## Margem acima do topo da tela que já conta como "na estrada" para a meta de
## densidade: cobre a latência de aproximação dos recém-nascidos.
const MARGEM_PISTA: float = 60.0


## NPCs já na tela ou entrando por cima, dentro da margem de aproximação.
func _contar_na_pista() -> int:
	var n: int = 0
	for v in active_vehicles:
		if v.category == null:
			continue
		var meia_y: float = v.category.size.y * 0.5
		if v.position.y + meia_y >= -MARGEM_PISTA:
			n += 1
	return n


## NPCs com pelo menos um pixel na área visível agora.
func _contar_visiveis() -> int:
	var vista: Rect2 = _retangulo_de_visao()
	var n: int = 0
	for v in active_vehicles:
		if v.category == null:
			continue
		var meia: Vector2 = v.category.size * 0.5
		if (
			v.position.y + meia.y >= vista.position.y and v.position.y - meia.y <= vista.end.y
			and v.position.x + meia.x >= vista.position.x and v.position.x - meia.x <= vista.end.x
		):
			n += 1
	return n


## Máximo de NPCs visíveis para a dificuldade do ambiente corrente.
## Sem correspondência configurada, cai no próprio `traffic_min_visible`.
func _maximo_visivel_atual() -> int:
	var ambiente: Dictionary = GameConfig.ENVIRONMENTS.get(GameConfig.current_environment_id, {})
	var dificuldade: int = int(ambiente.get("difficulty", 1))
	return int(GameConfig.traffic_max_visible_by_difficulty.get(dificuldade, GameConfig.traffic_min_visible))


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

## Tenta nascer um veículo na altura `y`. Com `categoria_adiada` (FR-029) a
## categoria vem do pendente em vez do sorteio — é a revalidação do quadro
## seguinte, com o y e as posições dos ativos já atualizados.
func _tentar_spawn(
	road: Road, em_enchimento: bool = false, categoria_adiada: TrafficData = null
) -> void:
	# I1 / FR-005 / FR-042: o teto continua ANTES da validação de spawn
	# (contrato spawn_validation.md §Garantias).
	if active_vehicles.size() >= GameConfig.traffic_max_vehicles:
		return

	var categoria: TrafficData = categoria_adiada
	if categoria == null:
		categoria = _sortear_categoria()
	if categoria == null:
		return

	# I3: nasce acima da área visível, com folga igual à própria altura.
	# Em enchimento, a faixa é curta e logo acima da tela (reposição rápida);
	# no fluxo normal, a faixa de distância com variância dessincroniza os
	# births para evitar saídas em bloco depois (o "lote" do ajuste 3/4).
	var y: float
	if em_enchimento:
		y = -categoria.size.y - GameConfig.traffic_spawn_fill_distance
	else:
		y = (
			-categoria.size.y - GameConfig.traffic_spawn_distance
			- randf() * GameConfig.traffic_spawn_distance_variance
		)

	# FR-014 / I2: valida a faixa livre NA ALTURA DE CRIAÇÃO, não na do jogador.
	var bounds: Dictionary = road.get_boundaries_for_player_y(y)
	var min_x: float = _menor_x_livre(categoria, bounds)
	var max_x: float = _maior_x_livre(categoria, bounds)
	if max_x - min_x <= 0.0:
		return

	# FR-019: espaçamento longitudinal verificado antes de criar.
	# EXCEÇÃO (ajuste 3/4): abaixo do mínimo visível o birth é invisível e a
	# separação retangular de 12 px já impede sobreposição — checar os 70 px
	# aqui transformaria o enchimento num gargalo de ~2,5 s por birth.
	if not em_enchimento and _espaco_longo_insuficiente(y):
		return

	var veiculo: TrafficVehicle = _obter_do_pool()

	if validador == null:
		# Caminho legado do SPEC-004 (SC-016): faixa única da velocidade,
		# sem consulta — nada muda para quem não liga o validador.
		var lane: float = _sortear_faixa_separada(categoria, y, min_x, max_x)
		if lane < 0.0:
			return
		_nascer(veiculo, categoria, lane, y, bounds)
		return

	# FR-028/FR-029: a faixa pretendida primeiro, depois as demais da mais
	# próxima. Cada candidata passa pelas regras do SPEC-004 (separação e
	# ordenação do corredor) e pelo validador do SPEC-006; esgotadas todas,
	# o nascimento é ADIADO — a próxima chamada (o quadro seguinte) revalida.
	for x in _faixas_candidatas(categoria, min_x, max_x):
		if not _separacao_respeitada(categoria, x, y):
			continue
		if not _ordenacao_valida(categoria, x, y):
			continue
		var resultado: Dictionary = validador.validar_spawn(categoria, x, y, bounds)
		if bool(resultado.aceito):
			_spawn_pendente = {}
			_nascer(veiculo, categoria, float(resultado.x), float(resultado.y), bounds)
			return
	_spawn_pendente = {"categoria": categoria}


## Ponto único de nascimento (legado e validado): ativa, posiciona, coloca na
## cena se preciso e registra no conjunto ativo com o sinal de spawn.
func _nascer(
	veiculo: TrafficVehicle, categoria: TrafficData, x: float, y: float, bounds: Dictionary
) -> void:
	veiculo.activate(categoria, x, y)
	veiculo.position.x = x
	veiculo.previous_right_boundary = bounds.get("right", 0.0)
	# O nó já tem este manager como pai: veio do pool, ou foi criado e anexado
	# em `_obter_do_pool`. Anexar de novo aqui causaria erro de reparenting.
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


## Faixa reservada da categoria (ajuste 5): cada velocidade distinta ocupa uma
## faixa fixa da pista — mais rápido à esquerda, mais lento à direita (regra de
## trânsito). Faixas distintas ficam com as projeções laterais separadas
## (`traffic_min_separation` de folga), então velocidades diferentes nunca
## compartilham um corredor: o comboio vira estruturalmente impossível e as
## categorias lentas nascem toda vez que a própria faixa está livre, sem
## starving (FR-007, FR-019, FR-023).
## Velocidades máximas distintas entre as categorias, em ordem crescente —
## a base do mapeamento velocidade → faixa reservada (ajuste 5).
func _velocidades_distintas() -> Array[float]:
	var distintas: Array[float] = []
	for id in categories:
		var velocidade: float = categories[id].max_speed
		if not distintas.has(velocidade):
			distintas.append(velocidade)
	distintas.sort()
	return distintas


## Todas as posições de faixa da pista: uma por velocidade distinta, índice
## 0 = mais rápido = extremo esquerdo (ajuste 5, FR-007).
func _faixas_por_velocidade(min_x: float, max_x: float) -> Array[float]:
	var distintas := _velocidades_distintas()
	if distintas.size() <= 1:
		return [(min_x + max_x) * 0.5]
	var faixas: Array[float] = []
	for ordem in distintas.size():
		faixas.append(min_x + (max_x - min_x) * float(ordem) / float(distintas.size() - 1))
	return faixas


func _slot_da_categoria(categoria: TrafficData, min_x: float, max_x: float) -> float:
	var distintas := _velocidades_distintas()
	if distintas.size() <= 1:
		return (min_x + max_x) * 0.5
	# Índice 0 = mais rápido = extremo esquerdo da pista.
	var ordem: int = distintas.size() - 1 - distintas.find(categoria.max_speed)
	return _faixas_por_velocidade(min_x, max_x)[ordem]


## FR-029 — candidatas laterais de um nascimento: a faixa reservada da
## própria velocidade primeiro; depois as demais, da mais próxima da
## pretendida. Ordem determinística (research R9) — nenhuma aleatoriedade
## na escolha da alternativa.
func _faixas_candidatas(categoria: TrafficData, min_x: float, max_x: float) -> Array[float]:
	var propria: float = _slot_da_categoria(categoria, min_x, max_x)
	var ordenadas: Array[float] = [propria]
	var resto: Array[float] = []
	for x in _faixas_por_velocidade(min_x, max_x):
		if is_equal_approx(x, propria):
			continue
		resto.append(x)
	resto.sort_custom(
		func(a: float, b: float) -> bool: return absf(a - propria) < absf(b - propria)
	)
	ordenadas.append_array(resto)
	return ordenadas


## Devolve a faixa da categoria, ou -1 se ela não respeitar a separação mínima
## dos ativos ou a ordenação de velocidades do corredor (spawn adiado).
func _sortear_faixa_separada(categoria: TrafficData, y: float, min_x: float, max_x: float) -> float:
	var lane: float = _slot_da_categoria(categoria, min_x, max_x)
	if not _separacao_respeitada(categoria, lane, y):
		return -1.0
	if not _ordenacao_valida(categoria, lane, y):
		return -1.0
	return lane


## Ajuste 5 — ordenação de velocidades na coluna (FR-007, FR-019):
## num corredor (projeções laterais intersectadas) as categorias ficam ordenadas
## de baixo para cima (lentos embaixo, rápidos em cima). O recém-nascido ocupa o
## topo da coluna, então ele só nasce se:
##   - não houver ninguém ACIMA dele mais lento (quem nasce depois, mais rápido,
##     o alcançaria e o dois travariam na taxa do mais lento); nem
##   - ninguém ABAIXO mais rápido (o nascedo o alcançaria e os dois travariam).
## Com colunas ordenadas, na descida cada veículo sai do ecrã na taxa da própria
## categoria (caminhão a ≥ 28 px/s com o jogador no máximo) — era isso que o
## comboio apagava (caminhão colado no esporte, saindo a 4 px/s).
func _ordenacao_valida(categoria: TrafficData, x: float, y: float) -> bool:
	var vel_nova: float = categoria.max_speed
	for v in active_vehicles:
		if v.category == null:
			continue
		var folga_x: float = absf(v.position.x - x) - (v.category.size.x + categoria.size.x) * 0.5
		if folga_x >= 0.0:
			continue  # corredor distinto: ordenação não se aplica
		var vel_v: float = v.get_speed()
		if v.position.y < y and vel_v < vel_nova:
			return false  # acima e mais lento
		if v.position.y > y and vel_v > vel_nova:
			return false  # abaixo e mais rápido
	return true


## Verdadeiro quando o retângulo do novo veículo em (`x`, `y`) fica a pelo
## menos `traffic_min_separation` da borda de cada veículo ativo, nos dois
## eixos somados: separado em X OU em Y. Só falha se os retângulos se
## aproximam/abrem simultaneamente nos dois sentidos.
func _separacao_respeitada(categoria: TrafficData, x: float, y: float) -> bool:
	var s: float = GameConfig.traffic_min_separation
	for v in active_vehicles:
		if v.category == null:
			continue
		var folga_x: float = absf(v.position.x - x) - (v.category.size.x + categoria.size.x) * 0.5
		var folga_y: float = absf(v.position.y - y) - (v.category.size.y + categoria.size.y) * 0.5
		if folga_x < s and folga_y < s:
			return false
	return true


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
##
## O líder precisa estar NO MESMO CORREDOR: as projeções laterais dos dois
## veículos precisam se INTERSECTAR (`folga_x < 0`). Pares lado a lado, mesmo
## com folga lateral de 1 px, nunca se sobrepõem em Y e por isso não podem ser
## acoplados — sem essa regra, colunas vizinhas herdavam a velocidade umas das
## outras (ajuste 5: caminhão saindo na taxa do esporte).
func _lider_mais_proximo(i: int, y0: float, para_baixo: bool) -> int:
	var melhor: int = -1
	var menor_gap: float = INF
	var vi: TrafficVehicle = active_vehicles[i]
	var meia_i: float = vi.category.size.x * 0.5 if vi.category != null else 0.0
	for j in active_vehicles.size():
		if j == i:
			continue
		var vj: TrafficVehicle = active_vehicles[j]
		var meia_j: float = vj.category.size.x * 0.5 if vj.category != null else 0.0
		var folga_x: float = absf(vj.position.x - vi.position.x) - (meia_i + meia_j)
		if folga_x >= 0.0:
			continue  # corredor distinto: não é líder deste veículo
		var gap: float = vj.position.y - y0
		if para_baixo:
			if gap > 0.0 and gap < menor_gap:
				menor_gap = gap
				melhor = j
		elif gap < 0.0 and -gap < menor_gap:
			menor_gap = -gap
			melhor = j
	return melhor


## Espaçamento longitudinal mínimo centro-a-centro entre `i` e `lider`:
## nunca menor que `traffic_min_spacing`, mas sempre grande o bastante para as
## alturas dos dois veículos mais `traffic_min_separation` de folga — senão o
## limitador permite grudar (caminhão de 128 px fechando para 70 px de centros
## = 26 px de sobreposição; ajuste 5).
func _espaco_min_centros(i: int, lider: int) -> float:
	var meias: float = 0.0
	var vi: TrafficVehicle = active_vehicles[i]
	var vl: TrafficVehicle = active_vehicles[lider]
	if vi.category != null:
		meias += vi.category.size.y * 0.5
	if vl.category != null:
		meias += vl.category.size.y * 0.5
	return maxf(
		GameConfig.traffic_min_spacing,
		meias + GameConfig.traffic_min_separation
	)


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
				- _espaco_min_centros(i, lider) - FOLGA_ESPACAMENTO
			)
	elif dy < 0.0:
		var lider: int = _lider_mais_proximo(i, y0, false)
		if lider >= 0:
			limite = (
				_espaco_min_centros(i, lider) + FOLGA_ESPACAMENTO
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


## Reset de corrida (SPEC-008, FR-035, research R10): todos os ativos voltam
## ao pool e o estado de geração volta ao inicial. Idempotente; nenhum sinal
## de spawn/reciclagem novo além dos já emitidos por `_desativar`.
func reset() -> void:
	for i in range(active_vehicles.size() - 1, -1, -1):
		_desativar(active_vehicles[i])
	active_vehicles.clear()
	_cronometro_spawn = 0.0
	_habilitado = true
	_spawn_pendente = {}
	_dy_desejado.clear()
	_y_futuro.clear()
	_ordem_desc.clear()
	_ordem_asc.clear()