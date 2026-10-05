class_name CollisionSystem
extends RefCounted

## Sistema de detecção e resolução de colisão jogador↔NPC (SPEC-005).
##
## Componente separado do trânsito (FR-033): consome posição, velocidade e área
## ocupada dos NPCs (contrato consumed_apis.md §1) e os limites vigentes da
## estrada por altura (§2); nunca cria, move longitudinally nem recicla NPCs.
## Não escreve em combustível, pontuação ou dano (FR-030) — apenas emite o
## sinal `collision_occurred` para specs futuras (contracts/collision_event.md).
## Colisões NPC×NPC e com decoração não existem (FR-031).

signal collision_occurred(data: CollisionData)

## Estado do drift do jogador (FR-015). Público para testes e wiring.
var drift: DriftState = DriftState.new()

## Cooldown por par jogador↔NPC: instance_id → tempo restante (R5, FR-026/027).
var _cooldowns: Dictionary = {}

## Pares atualmente sobrepostos: novo impacto exige separação e novo contato
## (spec §Assumptions — o cooldown protege o impacto, não o veículo).
var _sobrepostos: Dictionary = {}

## Última velocidade relativa/intensidade calculadas (exposto para testes).
var ultima_intensidade: float = 0.0


## Hitbox do jogador, centrada na posição, exclusivamente por configuração
## (FR-006/FR-008: a lógica nunca consulta o sprite).
func player_hitbox(player: Node2D) -> Rect2:
	var dim: Vector2 = GameConfig.player_hitbox_size
	return Rect2(player.position - dim * 0.5, dim)


## Hitbox do NPC pela categoria configurada (FR-007); fallback na área ocupada
## declarada pelo trânsito quando a categoria não tem configuração própria.
func npc_hitbox(npc: TrafficVehicle) -> Rect2:
	var dim: Vector2 = GameConfig.NPC_HITBOX_SIZES.get(npc.get_category_id(), Vector2.ZERO)
	return Rect2(npc.position - dim * 0.5, dim) if dim != Vector2.ZERO else npc.get_occupied_area()


## Avaliação de um quadro.
##
## `bounds_for_y` é um Callable (y: float) -> Dictionary {left, right} — a mesma
## fonte de `Road.get_boundaries_for_player_y` (contrato §2, FR-022/FR-023).
## Ordem: cooldown → drift vigente → detecção/consequências.
func update(delta: float, player: Node2D, npcs: Array, bounds_for_y: Callable) -> void:
	_decaCooldowns(delta)

	var bounds: Dictionary = bounds_for_y.call(player.position.y)
	_ultimos_bounds = bounds
	drift.update(delta, player, float(bounds.left), float(bounds.right))

	var caixa_jogador: Rect2 = player_hitbox(player)
	for npc in npcs:
		if npc == null or not npc.is_active():
			continue
		var id: int = npc.get_instance_id()
		var caixa_npc: Rect2 = npc_hitbox(npc)
		if caixa_jogador.intersects(caixa_npc):
			if _cooldowns.has(id) or _sobrepostos.has(id):
				# Cooldown: nem evento nem consequência (FR-028).
				# Sobreposto: mesmo impacto físico, já contabilizado (R5).
				continue
			_processar_colisao(player, npc, caixa_jogador, caixa_npc, bounds)
			_cooldowns[id] = GameConfig.collision_cooldown_time
			_sobrepostos[id] = true
		else:
			# Separação rearma o par para um NOVO contato (US5-CA3).
			_sobrepostos.erase(id)


## Classificação (FR-002, R2): eixo de menor penetração separa os veículos.
## Penetração horizontal menor → contato lateral; vertical menor → traseira,
## com o sinal de `dy` distinguindo quem atinge quem (FR-003).
func classificar(caixa_jogador: Rect2, caixa_npc: Rect2) -> int:
	var ox: float = _penetracao(caixa_jogador.position.x, caixa_jogador.end.x, caixa_npc.position.x, caixa_npc.end.x)
	var oy: float = _penetracao(caixa_jogador.position.y, caixa_jogador.end.y, caixa_npc.position.y, caixa_npc.end.y)
	if ox <= oy:
		return CollisionData.CollisionType.LATERAL
	var dy: float = caixa_jogador.get_center().y - caixa_npc.get_center().y
	return CollisionData.CollisionType.PLAYER_HITS_NPC_REAR if dy > 0.0 else CollisionData.CollisionType.NPC_HITS_PLAYER_REAR


static func _penetracao(a_min: float, a_max: float, b_min: float, b_max: float) -> float:
	return minf(a_max, b_max) - maxf(a_min, b_min)


## Direção do drift (FR-004/FR-005): lado relativo do jogador; dentro da margem
## neutra, lado com mais espaço trafegável na altura do jogador; empate → esquerda.
func direcao_drift(player: Node2D, npc: TrafficVehicle, bounds: Dictionary) -> int:
	var dx: float = player.position.x - npc.position.x
	if absf(dx) > GameConfig.collision_neutral_margin:
		return signi(int(dx * 1000.0))
	var espaco_dir: float = float(bounds.right) - player.position.x
	var espaco_esq: float = player.position.x - float(bounds.left)
	if espaco_dir > espaco_esq:
		return 1
	return -1


## Intensidade do impacto (FR-024/FR-025, R8): velocidade relativa no contato,
## normalizada e clampada em [0, 1].
func intensidade(player: Node2D, npc: TrafficVehicle) -> float:
	var relativa: float = absf(player.controller.speed - npc.get_speed())
	ultima_intensidade = clampf(relativa / GameConfig.collision_intensity_divisor, 0.0, 1.0)
	return ultima_intensidade


func _processar_colisao(player: Node2D, npc: TrafficVehicle, caixa_jogador: Rect2, caixa_npc: Rect2, bounds: Dictionary) -> void:
	var tipo: int = classificar(caixa_jogador, caixa_npc)
	var dir: int = direcao_drift(player, npc, bounds)
	# Velocidade relativa no instante do contato, antes de qualquer perda (FR-024).
	var relativa: float = absf(player.controller.speed - npc.get_speed())
	var inten: float = intensidade(player, npc)

	# Consequências do jogador: perda proporcional à intensidade (FR-009),
	# nunca abaixo de zero e nunca parada instantânea (FR-010).
	var perda: float = lerpf(GameConfig.collision_speed_loss_min, GameConfig.collision_speed_loss_max, inten)
	perda = minf(perda, player.controller.speed * 0.9)
	player.controller.speed = maxf(player.controller.speed - perda, 0.0)

	# Ajuste 4: a aceleração é desconsiderada por um tempo após o impacto —
	# sem isso, quem segura o acelera repõe a perda na hora e o jogador
	# "volta" à mesma posição, anulando a empurrada para trás do choque.
	player.controller.aceleracao_bloqueada = GameConfig.collision_accel_lockout_time

	# Drift com força/duração escaladas pela intensidade (FR-011/FR-012).
	# Substitui qualquer drift anterior pela última classificação (Edge Case).
	drift.iniciar(
		dir,
		lerpf(GameConfig.drift_force_min, GameConfig.drift_force_max, inten),
		lerpf(GameConfig.drift_duration_min, GameConfig.drift_duration_max, inten)
	)

	# Tipo 1-3: NPC não perde velocidade (FR-017) e recebe o deslocamento
	# oposto que viabiliza a ultrapassagem (FR-018/FR-019).
	if tipo == CollisionData.CollisionType.NPC_HITS_PLAYER_REAR:
		npc.apply_overtake_offset(-dir, GameConfig.npc_overtake_magnitude, GameConfig.npc_overtake_duration)

	# Exatamente um evento por colisão válida, com os 6 dados do contrato (FR-029).
	var data: CollisionData = CollisionData.new()
	data.player = player
	data.npc = npc
	data.tipo = tipo
	data.velocidade_impacto = relativa
	data.intensidade = inten
	data.direcao_drift = dir
	collision_occurred.emit(data)


## Limites usados pela última avaliação — alimenta direcao_drift no mesmo quadro.
var _ultimos_bounds: Variant = null


func _decaCooldowns(delta: float) -> void:
	var expirados: Array = []
	for id in _cooldowns:
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if float(_cooldowns[id]) <= 0.0:
			expirados.append(id)
	for id in expirados:
		_cooldowns.erase(id)
