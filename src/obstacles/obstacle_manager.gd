class_name ObstacleManager
extends Node2D

## Gerenciador de obstáculos (SPEC-011, FR-014…FR-020; research R6;
## contracts/obstacle_integration.md §1): espelho do FuelCanManager — pool
## pré-criada, movimento pela rolagem da estrada, geração por distância com
## validação de limites/espacamentos/NPCs/jogador e detecção própria SEM
## pipeline de colisão (AABB por quadro, research R3). Frequência constante
## entre modos (só o gate de desbloqueio difere — FR-018). Dependências
## apenas de leitura: Road, snapshot do trânsito, TrackManager e GameConfig.

signal obstacle_spawned(obstacle: Obstacle)
signal obstacle_hit(tipo: String)

## Conjunto reutilizável — reciclagem na base (saiu da tela) ou, no
## cascalho, também ao atingir; a poça atingida só sai na base (FR-014).
var pool: Array[Obstacle] = []

## Obstáculos visíveis — nunca acima de `obstaculo_max_ativos`.
var ativos: Array[Obstacle] = []

## Distância integrada desde o último nascimento (km) — zera no spawn.
var distancia_desde_ultima: float = 0.0

## Candidato invalidado, reavaliado a cada quadro até nascer ou expirar no
## próximo intervalo — nunca descartado antecipadamente (FR-030-análogo).
var spawn_pendente: Dictionary = {}

## Gate por corrida (FR-018/FR-019): falso ⇒ nenhum nascimento.
var disponivel: bool = true

## Y de nascimento (acima da tela) e margem lateral contra as bordas.
const Y_SPAWN: float = -40.0
const MARGEM_LATERAL: float = 16.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Monta o pool inicial e carrega as texturas (guardado — contrato §1
## `configurar`). Idempotente: só cria se não há ativos nem pool.
func configurar() -> void:
	if not pool.is_empty() or not ativos.is_empty():
		return
	for i in GameConfig.obstaculo_max_ativos:
		var item := Obstacle.new()
		add_child(item)
		item.preparar()
		item.reset_para_pool()
		pool.append(item)


## Quadro de PLAYING (passo 3.5 — depois dos galões): mover → reciclar na
## base → detectar contato com o jogador → gerar. Fora de PLAYING o
## GameplayManager nem chama (FR-023).
func update(
	delta: float,
	road: Road,
	npcs: Array,
	track: TrackManager,
	player: Node2D
) -> void:
	var rolagem: float = road.scroll_speed if road != null else 0.0

	# 1. Movimento pela rolagem e reciclagem de quem saiu da base.
	for i in range(ativos.size() - 1, -1, -1):
		var item: Obstacle = ativos[i]
		if rolagem > 0.0:
			item.position.y += rolagem * delta
		if item.position.y - item.tamanho.y * 0.5 > 480.0:
			_devolver(item)

	# 2. Detecção (research R3): AABB por quadro com o hitbox do jogador.
	if player != null:
		_detectar(player, road)

	# 3. Geração: só com estrada rolando (parado nada nasce — SC-022 análogo).
	if rolagem <= 0.0:
		return
	if track != null and player != null:
		var velocidade: float = _velocidade_do(player, rolagem)
		distancia_desde_ultima += maxf(velocidade, 0.0) \
			* GameConfig.track_units_to_km * delta
	_tentar_gerar(road, npcs, track, player)


## Todos ao pool, distância e pendência zerados — largada e encerramento.
## O gate `disponivel` é preservado (definido por corrida no reset do
## orquestrador — research R6). Idempotente.
func reset() -> void:
	for i in range(ativos.size() - 1, -1, -1):
		_devolver(ativos[i])
	ativos.clear()
	distancia_desde_ultima = 0.0
	spawn_pendente = {}


## Abre/fecha o gate de nascimento do modo (FR-018/FR-019). Obstáculos já
## ativos continuam rolando até sair — em prática o gate é definido antes
## de qualquer nascimento (no reset da largada).
func definir_disponivel(flag: bool) -> void:
	disponivel = flag


## Detecção um a um, de trás para frente (FR-014 ajustado no aceite T032):
## POÇA ⇒ desvio lateral de meio carro pela posição do impacto e a poça
## fica INERTE na pista (estado ATINGIDO — continua rolando até sair da
## tela, nunca some no impacto); CASCALHO ⇒ efeito temporizado no veículo +
## reciclagem imediata (o efeito vive no veículo, não no item).
func _detectar(player: Node2D, road: Road) -> void:
	var caixa_jogador := Rect2(
		player.position - GameConfig.player_hitbox_size * 0.5,
		GameConfig.player_hitbox_size
	)
	for i in range(ativos.size() - 1, -1, -1):
		var item: Obstacle = ativos[i]
		if item.estado != Obstacle.Estado.ATIVO:
			continue
		if not item.area_contato().intersects(caixa_jogador):
			continue
		if item.tipo == Obstacle.TIPO_CASCALHO:
			_aplicar_efeito_cascalho(player)
			obstacle_hit.emit(item.tipo)
			_devolver(item)
		else:
			_desviar_jogador(item, player, road)
			item.estado = Obstacle.Estado.ATINGIDO
			obstacle_hit.emit(item.tipo)


## Desvio lateral da poça (FR-014 ajustado): o carro é empurrado por
## `poca_desvio_lateral` (meio carro) para o lado da posição do impacto —
## centro do carro à esquerda do centro da poça ⇒ desvia para a esquerda;
## caso contrário, para a direita. Clamp nas bordas vigentes da pista
## (nunca empurra para fora da faixa).
func _desviar_jogador(item: Obstacle, player: Node2D, road: Road) -> void:
	var lado: float = -1.0 if player.position.x <= item.position.x else 1.0
	var desvio: float = GameConfig.poca_desvio_lateral * lado
	var esquerda: float = GameConfig.road_left_boundary
	var direita: float = GameConfig.road_right_boundary
	if road != null:
		esquerda = road.left_boundary
		direita = road.right_boundary
	var meia_largura: float = GameConfig.player_hitbox_size.x * 0.5
	player.position.x = clampf(
		player.position.x + desvio,
		esquerda + meia_largura,
		direita - meia_largura
	)


## Efeito temporizado do CASCALHO no veículo (FR-015, research R5):
## parâmetros sempre do GameConfig (§IV) — o manager não tem números próprios.
func _aplicar_efeito_cascalho(player: Node2D) -> void:
	var controller = player.get("controller")
	if controller == null or not controller.has_method("aplicar_efeito_cascalho"):
		return
	controller.aplicar_efeito_cascalho(
		GameConfig.cascalho_duracao,
		GameConfig.cascalho_velocidade_fator,
		GameConfig.cascalho_aderencia_fator
	)


## Regras de geração (FR-017, research R6): gate, teto simultâneo, offsets
## da largada/chegada, intervalo por distância e validação total do
## candidato. Posição inválida ⇒ mantida pendente e reavaliada (FR-030-análogo).
func _tentar_gerar(road: Road, npcs: Array, track: TrackManager, player: Node2D) -> void:
	if not disponivel:
		return
	if ativos.size() >= GameConfig.obstaculo_max_ativos:
		return
	if track != null:
		if track.get_percorrida() < GameConfig.obstaculo_start_offset_km:
			return
		if track.get_restante() < GameConfig.obstaculo_finish_offset_km:
			return

	var intervalo: float = maxf(GameConfig.obstaculo_intervalo_km, 0.01)

	if spawn_pendente.is_empty():
		if distancia_desde_ultima < intervalo:
			return
		# O tipo é sortead ANTES do X: a faixa válida de centro depende da
		# meia-largura do sprite (margem fixa de 16 px < 24 px da poça
		# gerava candidatos fora dos limites — pendência crônica).
		var tipo_novo: String = _sortear_tipo()
		spawn_pendente = {
			"x": _sortear_x(road, _meio_do(tipo_novo).x),
			"tipo": tipo_novo,
		}
	else:
		if distancia_desde_ultima >= intervalo * 2.0:
			# Expira no próximo intervalo e reinicia a integra (FR-030-análogo).
			spawn_pendente = {}
			distancia_desde_ultima = 0.0
			return

	var x_cand: float = float(spawn_pendente.get("x", -1.0))
	var tipo_cand: String = String(spawn_pendente.get("tipo", Obstacle.TIPO_POCA))
	if x_cand < 0.0:
		spawn_pendente = {}
		return
	var meio: Vector2 = _meio_do(tipo_cand)
	if not _posicao_valida(Vector2(x_cand, Y_SPAWN), meio, road, npcs, player):
		return
	_nascer(tipo_cand, Vector2(x_cand, Y_SPAWN))
	spawn_pendente = {}
	distancia_desde_ultima = 0.0


## Validação (FR-017, contrato §1.3): dentro dos limites vigentes,
## `obstaculo_min_spacing` de qualquer outro obstáculo ativo, sem interseção
## com NPCs (retângulo inflado por `obstaculo_npc_spacing`) e nunca perto o
## suficiente do jogador para nascer sobre ele.
func _posicao_valida(
	pos: Vector2, meio: Vector2, road: Road, npcs: Array, player: Node2D
) -> bool:
	var esquerda: float = GameConfig.road_left_boundary
	var direita: float = GameConfig.road_right_boundary
	if road != null:
		esquerda = road.left_boundary
		direita = road.right_boundary
	if pos.x - meio.x < esquerda or pos.x + meio.x > direita:
		return false

	for item in ativos:
		var dx: float = absf(item.position.x - pos.x)
		var dy: float = absf(item.position.y - pos.y)
		if dx < GameConfig.obstaculo_min_spacing and dy < GameConfig.obstaculo_min_spacing:
			return false

	var caixa := Rect2(pos - meio, meio * 2.0).grow(GameConfig.obstaculo_npc_spacing)
	for npc in npcs:
		if npc == null or not npc.has_method("get_occupied_area"):
			continue
		if caixa.intersects(npc.get_occupied_area()):
			return false

	if player != null:
		var meia_jogador: Vector2 = GameConfig.player_hitbox_size * 0.5
		var caixa_jogador := Rect2(player.position - meia_jogador, meia_jogador * 2.0)
		if caixa.intersects(caixa_jogador):
			return false
	return true


## Sorteio de tipo pelos pesos configuráveis (FR-026) — 50/50 no padrão.
func _sortear_tipo() -> String:
	var peso_poca: int = maxi(GameConfig.obstaculo_peso_poca, 0)
	var peso_cascalho: int = maxi(GameConfig.obstaculo_peso_cascalho, 0)
	var total: int = peso_poca + peso_cascalho
	if total <= 0:
		return Obstacle.TIPO_POCA
	return Obstacle.TIPO_CASCALHO if randi_range(0, total - 1) >= peso_poca \
		else Obstacle.TIPO_POCA


func _meio_do(tipo: String) -> Vector2:
	if tipo == Obstacle.TIPO_CASCALHO:
		return GameConfig.obstaculo_tamanho_cascalho * 0.5
	return GameConfig.obstaculo_tamanho_poca * 0.5


## Sorteia o X do centro dentro da faixa em que o sprite cabe na pista
## (limites vigentes + meia-largura + margem). Faixa invertida (pista
## estreita demais) ainda devolve um valor — a validação o rejeita e o
## candidato fica pendente, nunca nasce inválido.
func _sortear_x(road: Road, meia_largura: float) -> float:
	var esquerda: float = GameConfig.road_left_boundary
	var direita: float = GameConfig.road_right_boundary
	if road != null:
		esquerda = road.left_boundary
		direita = road.right_boundary
	var minimo: float = esquerda + meia_largura + MARGEM_LATERAL
	var maximo: float = direita - meia_largura - MARGEM_LATERAL
	return randf_range(minimo, maximo)


func _nascer(tipo: String, pos: Vector2) -> void:
	var item: Obstacle = _obter_do_pool()
	if item == null:
		return
	item.definir_tipo(tipo)
	ativos.append(item)
	item.ativar(pos)
	obstacle_spawned.emit(item)


func _obter_do_pool() -> Obstacle:
	while not pool.is_empty():
		var item: Obstacle = pool.pop_back()
		if item != null:
			return item
	# Pool esgotada: cria sob demanda — o teto continua em `obstaculo_max_ativos`
	# porque o próprio `_tentar_gerar` limita os ativos.
	var novo := Obstacle.new()
	add_child(novo)
	novo.preparar()
	return novo


func _devolver(item: Obstacle) -> void:
	var indice: int = ativos.find(item)
	if indice != -1:
		ativos.remove_at(indice)
	item.reset_para_pool()
	if not pool.has(item):
		pool.append(item)


func _velocidade_do(player: Node2D, rolagem: float) -> float:
	if player.has_method("get_speed"):
		return player.get_speed()
	var fator: float = GameConfig.scroll_multiplier
	if fator <= 0.0:
		return 0.0
	return rolagem / fator
