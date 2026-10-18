class_name FuelCanManager
extends Node2D

## Gerenciador de galões (SPEC-008, FR-019…FR-038): pool no estilo
## TrafficManager (R6), movimento pela rolagem da estrada (Clarificação — sem
## velocidade própria), geração por distância com taxa por ambiente e
## piso/teto por corrida (R7) e coleta própria SEM pipeline de colisão (R8).
## Dependências apenas de leitura: Road, snapshot do trânsito, TrackManager e
## GameConfig — testável sem a árvore de cena.

signal fuel_can_spawned(can: FuelCan)
signal fuel_can_collected(restaurado: float)

## Conjunto reutilizável — reciclagem obrigatória na base (FR-030, SC-011).
var pool: Array[FuelCan] = []

## Galões visíveis — nunca acima de `fuel_can_max_active` (data-model §4).
var ativos: Array[FuelCan] = []

## Total gerado na corrida — domínio de `fuel_can_min/max_per_race` (Clarificação).
var gerados_na_corrida: int = 0

## Distância integrada desde o último nascimento (km) — zera no spawn (R7).
var distancia_desde_ultima: float = 0.0

## Candidato invalidado, reavaliado a cada quadro até nascer ou expirar no
## próximo intervalo — nunca descartado antecipadamente (FR-030, R7).
var spawn_pendente: Dictionary = {}

## Y de nascimento (acima da tela) e margem lateral contra as bordas.
const Y_SPAWN: float = -40.0
const MARGEM_LATERAL: float = 16.0

## Configuração efetiva injetada pelo GameplayManager (SPEC-009, FR-008):
## `frequencia_galoes` (taxa por ambiente × fator) e `distancia_galoes`
## (intervalo × fator). Nulo = 1,0 nos dois — testes legados intactos (R12).
var dificuldade: DifficultyManager = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Monta o pool inicial. Idempotente: só cria se não há galões nem ativos.
func setup() -> void:
	if not pool.is_empty() or not ativos.is_empty():
		return
	for i in GameConfig.fuel_can_max_active:
		var can := FuelCan.new()
		add_child(can)
		can.preparar()
		can.reset_para_pool()
		pool.append(can)


## Quadro de PLAYING (R9, passo 3): mover → reciclar na base → coletar →
## gerar. Fora de PLAYING o GameplayManager nem chama (FR-024/AS7).
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
		var can: FuelCan = ativos[i]
		if rolagem > 0.0:
			can.position.y += rolagem * delta
		if can.position.y - can.tamanho.y * 0.5 > 480.0:
			_devolver(can)

	# 2. Coleta própria (R8): sobreposição de retângulos, sem CollisionSystem.
	if player != null:
		_coletar(player)

	# 3. Geração: só com estrada rolando (SC-022 análogo — parado nada nasce).
	if rolagem <= 0.0:
		return
	if track != null and player != null:
		var velocidade: float = _velocidade_do(player, rolagem)
		distancia_desde_ultima += maxf(velocidade, 0.0) \
			* GameConfig.track_units_to_km * delta
	_tentar_gerar(road, npcs, track)


## Todos ao pool, contadores zerados, pendências limpas — largada e
## encerramento (data-model §4, SC-011). Idempotente.
func reset() -> void:
	for i in range(ativos.size() - 1, -1, -1):
		_devolver(ativos[i])
	ativos.clear()
	gerados_na_corrida = 0
	distancia_desde_ultima = 0.0
	spawn_pendente = {}


## Coleta um a um, de trás para frente, emitindo 1× por galão e devolvendo ao
## pool no mesmo quadro (R8): sobreposição por vários quadros coleta uma vez.
func _coletar(player: Node2D) -> void:
	var caixa_jogador := Rect2(
		player.position - GameConfig.player_hitbox_size * 0.5,
		GameConfig.player_hitbox_size
	)
	for i in range(ativos.size() - 1, -1, -1):
		var can: FuelCan = ativos[i]
		if can.estado != FuelCan.Estado.ATIVO:
			continue
		if can.area_contato().intersects(caixa_jogador):
			can.estado = FuelCan.Estado.COLETADO
			_devolver(can)
			fuel_can_collected.emit(GameConfig.fuel_can_restore_amount)


## Regras de geração de R7 — distância com taxa por ambiente, piso/teto por
## corrida, offsets da largada/chegada, teto simultâneo, espaçamentos e
## ausência de NPCs. Posição inválida ⇒ adiada (FR-030), nunca re-sortida.
func _tentar_gerar(road: Road, npcs: Array, track: TrackManager) -> void:
	if ativos.size() >= GameConfig.fuel_can_max_active:
		return
	if gerados_na_corrida >= GameConfig.fuel_can_max_per_race:
		return
	if track != null:
		if track.get_percorrida() < GameConfig.fuel_can_start_offset:
			return
		if track.get_restante() < GameConfig.fuel_can_finish_offset:
			return

	var taxa: float = _taxa_efetiva()
	var intervalo: float = _intervalo_efetiva(taxa)
	# Piso por corrida antecipa o nascimento (intervalo × 0.5) até o mínimo.
	var antecipado: bool = gerados_na_corrida < GameConfig.fuel_can_min_per_race
	var corte: float = intervalo * (0.5 if antecipado else 1.0)

	if spawn_pendente.is_empty():
		if distancia_desde_ultima < corte:
			return
		spawn_pendente = {"x": _sortear_x(road)}
	else:
		if distancia_desde_ultima >= intervalo * 2.0:
			# Expira no próximo intervalo e reinicia a integra (FR-030, R7).
			spawn_pendente = {}
			distancia_desde_ultima = 0.0
			return

	var x_cand: float = float(spawn_pendente.get("x", -1.0))
	if x_cand < 0.0:
		spawn_pendente = {}
		return
	if not _posicao_valida(Vector2(x_cand, Y_SPAWN), road, npcs):
		return
	_nascer(Vector2(x_cand, Y_SPAWN))
	spawn_pendente = {}
	distancia_desde_ultima = 0.0
	gerados_na_corrida += 1


## Taxa de spawn efetiva (SPEC-009, FR-008, data-model §2): taxa por
## ambiente × `frequencia_galoes` do modo. Sem injeção → 1,0 (R12).
func _taxa_efetiva() -> float:
	var base: float = float(
		GameConfig.fuel_can_spawn_rate.get(GameConfig.current_environment_id, 1.0)
	)
	var fator: float = 1.0
	if dificuldade != null:
		fator = dificuldade.fator_frequencia_galoes()
	return base * fator


## Intervalo de distância efetiva (SPEC-009, FR-008): intervalo-base ×
## `distancia_galoes` do modo / taxa (piso 0,01 — divisão sempre finita).
func _intervalo_efetiva(taxa: float) -> float:
	var fator: float = 1.0
	if dificuldade != null:
		fator = dificuldade.fator_distancia_galoes()
	return (
		GameConfig.fuel_can_spawn_interval_distance * fator
		/ maxf(taxa, 0.01)
	)


## Validação do candidato (FR-022/FR-030, R7): dentro dos limites vigentes,
## `fuel_can_min_spacing` de qualquer eixo dos galões ativos e sem interseção
## com NPCs (retângulo inflado por `fuel_can_npc_spacing`).
func _posicao_valida(pos: Vector2, road: Road, npcs: Array) -> bool:
	var esquerda: float = GameConfig.road_left_boundary
	var direita: float = GameConfig.road_right_boundary
	if road != null:
		esquerda = road.left_boundary
		direita = road.right_boundary
	var meia: Vector2 = Vector2(32.0, 51.0) * 0.5
	if pos.x - meia.x < esquerda or pos.x + meia.x > direita:
		return false

	for can in ativos:
		var dx: float = absf(can.position.x - pos.x)
		var dy: float = absf(can.position.y - pos.y)
		if dx < GameConfig.fuel_can_min_spacing and dy < GameConfig.fuel_can_min_spacing:
			return false

	var caixa := Rect2(pos - meia, meia * 2.0).grow(GameConfig.fuel_can_npc_spacing)
	for npc in npcs:
		if npc == null or not npc.has_method("get_occupied_area"):
			continue
		var ocupada: Rect2 = npc.get_occupied_area()
		if caixa.intersects(ocupada):
			return false
	return true


func _sortear_x(road: Road) -> float:
	var esquerda: float = GameConfig.road_left_boundary
	var direita: float = GameConfig.road_right_boundary
	if road != null:
		esquerda = road.left_boundary
		direita = road.right_boundary
	return randf_range(esquerda + MARGEM_LATERAL, direita - MARGEM_LATERAL)


func _nascer(pos: Vector2) -> void:
	var can: FuelCan = _obter_do_pool()
	if can == null:
		return
	ativos.append(can)
	can.ativar(pos)
	fuel_can_spawned.emit(can)


func _obter_do_pool() -> FuelCan:
	while not pool.is_empty():
		var can: FuelCan = pool.pop_back()
		if can != null:
			return can
	# Pool esgotado: cria sob demanda — o teto continua em `fuel_can_max_active`
	# porque o próprio `_tentar_gerar` limita os ativos.
	var novo := FuelCan.new()
	add_child(novo)
	novo.preparar()
	return novo


func _devolver(can: FuelCan) -> void:
	var indice: int = ativos.find(can)
	if indice != -1:
		ativos.remove_at(indice)
	can.reset_para_pool()
	if not pool.has(can):
		pool.append(can)


func _velocidade_do(player: Node2D, rolagem: float) -> float:
	if player.has_method("get_speed"):
		return player.get_speed()
	var fator: float = GameConfig.scroll_multiplier
	if fator <= 0.0:
		return 0.0
	return rolagem / fator
