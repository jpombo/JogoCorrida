class_name NpcCollisionSystem
extends RefCounted

## Sistema de detecção e resolução de colisão NPC×NPC (SPEC-006).
##
## Componente separado do trânsito (FR-036): consome posição, área ocupada e
## velocidade dos NPCs ativos (contrato consumed_apis.md §1) e os limites
## vigentes da estrada por altura (§2); nunca cria, move longitudinalmente nem
## recicla veículos. O jogador NUNCA entra em nenhum campo de avaliação
## (FR-009) — o SPEC-005 continua sendo o único detector de contato
## jogador↔NPC (FR-037/FR-038, contrato §4).
##
## Avaliação por par, em duas camadas (data-model §1):
## - Contato (interseção de hitboxes): por quadro, barato — é o que dispara
##   consequências, sempre com latch de episódio (T007, FR-026).
## - Previsão (janela/TTC): sob demanda e periódica, com cache de pares
##   reconstruído só quando o conjunto de ativos muda (FR-007/FR-008).

signal npc_collision_occurred(data: NpcCollisionData)

## Latch de sobreposição por par canônico (chave `"minId:maxId"`). Presente
## enquanto o par está se tocando: o episódio atual já teve sua consequência
## aplicada uma única vez; a separação apaga a chave e rearma o par para um
## novo contato (FR-026, data-model §5). Sem isso, todo quadro de sobreposição
## reiniciaria o drift antes mesmo de o cooldown de T032 existir.
var _sobrepostos: Dictionary = {}

## Cache de pares candidatos na ordem determinística de processamento
## (y do mais acima, instance_id) — reconstruído sob demanda, nunca por
## quadro (FR-008, data-model §1, research R9).
var _pares: Array = []

## Conjunto de instance_ids usado na última construção: detecta mudanças do
## pool de ativos por quadro em O(n) e invalida o cache sem depender de sinais
## (os sinais de evento entram na reavaliação da US8, T048).
var _ids_construcao: Dictionary = {}

## Bandeira forçada de reconstrução (chamada por `marcar_reavaliacao`).
var _pares_sujos: bool = true

## Velocidade de scroll da estrada na última avaliação — necessária ao
## cálculo da janela de atividade, que depende do movimento relativo real
## (FR-004, research R1). Alimentada pelo chamador a cada quadro.
var _velocidade_estrada: float = 0.0

## Callable de limites por altura da avaliação corrente — alimenta a direção
## do drift (lado com mais espaço) no mesmo quadro, na altura do atingido
## (FR-018, contrato §2).
var _bounds_for_y: Callable = Callable()

## Cadeias ativas por id (data-model §3) — criadas sob impacto, expiradas
## por `npc_chain_timeout`; a varredura de vencidas roda só na criação da
## próxima cadeia (event-driven, sem alocação por quadro, FR-045).
var _cadeias: Dictionary = {}

## Próximo id de cadeia — monotônico crescente, nunca reutilizado durante a
## partida (data-model §3).
var _proximo_id_cadeia: int = 1

## Cooldown por PAR canônico: chave `"minId:maxId"` → tempo_restante
## (FR-026, research R5). Enquanto > 0 o par não gera evento NEM
## consequência (FR-027); rearmento exige expiração E separação.
var _cooldowns: Dictionary = {}

## Veredito `potencial` por par canônico (chave → bool) — cache curto de
## previsão (data-model §1): atualizado sob demanda, na reconstrução do cache
## e pela reavaliação periódica; NUNCA todos os pares por quadro (FR-007,
## FR-008).
var _vereditos: Dictionary = {}

## Cronômetro da reavaliação periódica (FR-008, npc_reevaluation_interval).
var _tempo_reavaliacao: float = 0.0

## Velocidade da estrada na ÚLTIMA reavaliação (FR-032, R8): a variação desde
## este ponto, acima de `npc_player_speed_change_threshold`, dispara a
## reavaliação imediata dos vereditos — frear/acelerar é refletido sem esperar
## o tique periódico (FR-034).
var _ultima_velocidade_reavaliada: float = 0.0

## Total de reavaliações disparadas (`avaliar_pares`) — introspecção para
## SC-012 (acessador público `total_reavaliacoes`, precedente T036).
var _total_reavaliacoes: int = 0

## Ativos da última avaliação — a MESMA referência consumida por
## `validar_spawn` (FR-028, contrato spawn_validation.md). Sem cópia e sem
## alocação por quadro (R9): o nascimento do quadro seguinte consulta esta
## lista com as posições do quadro anterior (um quadro de atraso — no
## gameplay o trânsito atualiza antes deste sistema); o adiamento quadro a
## quadro de FR-029 acompanha as posições atualizadas.
var _ativos_validacao: Array = []


## Avaliação de um quadro.
##
## `npcs` é a snapshot dos ativos (contrato §3); `bounds_for_y` é o Callable
## `(y) -> {left, right}` de `Road.get_boundaries_for_player_y` (contrato §2);
## `velocidade_estrada` é o scroll corrente da estrada (FR-004).
##
## Ordem: avanço dos drifts vigentes → revalidação do cache → reavaliação
## periódica → reavaliação por variação da velocidade do jogador (FR-032) →
## teste de contato por par. Os drifts correm ANTES
## do contato para que o deslocamento do quadro anterior esteja refletido na
## geometria, e o chamador registra este sistema ANTES do CollisionSystem do
## SPEC-005 para que um NPC já deslocado seja visto pelo detector de jogador
## no mesmo quadro (T035, R9).
func update(
	delta: float, npcs: Array, bounds_for_y: Callable, velocidade_estrada: float = 0.0
) -> void:
	_velocidade_estrada = velocidade_estrada
	_bounds_for_y = bounds_for_y
	_ativos_validacao = npcs

	_atualizar_drifts(delta, npcs, bounds_for_y)
	_avancar_cadeias(delta)
	_decrementar_cooldowns(delta)
	_revalidar_cache(npcs)
	_reavaliar_periodico(delta)
	# FR-032 / T047: variação relevante da velocidade do jogador desde a
	# última reavaliação → reavaliação imediata (R8). Roda DEPOIS do
	# periódico: se o periódico já disparou neste quadro, a variação medida
	# contra a referência recém-atualizada é zero e não há duplicação.
	if (
		absf(_velocidade_estrada - _ultima_velocidade_reavaliada)
		> GameConfig.npc_player_speed_change_threshold
	):
		avaliar_pares()

	for par in _pares:
		var a: TrafficVehicle = par.a
		var b: TrafficVehicle = par.b
		if not a.is_active() or not b.is_active():
			continue
		var chave: String = par.chave
		var caixa_a: Rect2 = npc_hitbox(a)
		var caixa_b: Rect2 = npc_hitbox(b)
		if caixa_a.intersects(caixa_b):
			if _sobrepostos.has(chave):
				# Mesmo episódio de contato, já contabilizado (FR-026).
				continue
			# FR-026/R5: cooldown do PAR — nenhum evento e nenhuma
			# consequência; pares distintos são independentes (SC-009).
			if _cooldowns.get(chave, 0.0) > 0.0:
				continue
			# FR-035 / T049: registrar exige interseção real E a regra da
			# janela satisfeita NO MOMENTO do contato. Sem janela → sem
			# evento e sem latch: o par segue sendo testado por quadro e
			# registra assim que a janela mudar (ex.: jogador freia, FR-032).
			if not _potencial(a, b):
				continue
			# Latch em QUALQUER episódio físico resolvido — processado OU
			# bloqueado por cadeia (FR-025/FR-027). Sem o latch no bloqueio,
			# o mesmo contato contínuo seria reavaliado a cada quadro e
			# viraria "impacto novo sem elo" assim que o drift do portador
			# terminasse — reabrindo o elo que a cadeia acabou de barrar
			# (CA2). Cooldown SÓ no processado: bloqueio não é episódio
			# contabilizado (FR-027 = sem evento e sem consequência).
			var processado: bool = _processar_novo_contato(a, b, caixa_a, caixa_b)
			_sobrepostos[chave] = true
			if processado:
				_cooldowns[chave] = GameConfig.npc_collision_cooldown
		else:
			# Separação rearma o par para um NOVO contato (data-model §5).
			_sobrepostos.erase(chave)
			# Rearmamento do cooldown exige expiração E separação (R5): com
			# os dois ainda sobrepostos, a chave sobrevive ao tempo zerado —
			# resolve o Edge Case "cooldown expira durante o contato".
			if _cooldowns.get(chave, 0.0) <= 0.0:
				_cooldowns.erase(chave)


## Força a reconstrução do cache no próximo quadro — chamado pelos eventos de
## spawn/reciclagem, início e fim de drift e sinais de pista (T048) e por
## testes.
func marcar_reavaliacao() -> void:
	_pares_sujos = true


## Recalcula o veredito de previsão de todos os pares do cache — gatilho da
## reavaliação periódica (FR-008), da variação de velocidade do jogador
## (FR-032), dos eventos (T048) e dos testes. A reavaliação só ATUALIZA
## vereditos: quem cria colisão é o contato real no `update`, nunca este
## método (FR-035). Atualiza a referência de velocidade do monitor FR-032 e o
## contador de SC-012.
func avaliar_pares() -> void:
	_total_reavaliacoes += 1
	_ultima_velocidade_reavaliada = _velocidade_estrada
	for par in _pares:
		_vereditos[par.chave] = _potencial(par.a, par.b)


## Total de reavaliações disparadas — introspecção de SC-012 (usada pelos
## testes de T046/T047; precedente dos acessores de T036).
func total_reavaliacoes() -> int:
	return _total_reavaliacoes


## Veredito sob demanda de um par (FR-007): lê o cache e calcula na hora se o
## par ainda não foi avaliado — nunca força a avaliação de todos os pares
## (FR-008). Insensível à ordem: a chave é o par canônico (data-model §5).
func tem_potencial(a: TrafficVehicle, b: TrafficVehicle) -> bool:
	var chave: String = chave_par(a.get_instance_id(), b.get_instance_id())
	if not _vereditos.has(chave):
		_vereditos[chave] = _potencial(a, b)
	return _vereditos[chave]


## Teto de NPCs ativos vigente (FR-042): PROJEÇÃO somente leitura do teto
## por dificuldade do SPEC-004 — nenhum valor armazenado aqui, a fonte única
## continua o `GameConfig` (data-model §6, research §Valores de configuração).
func npc_max_active() -> int:
	return GameConfig.npc_max_active()


## Pares no cache de avaliação corrente (introspecção para SC-011: com 5
## ativos, C(5,2) = 10 pares candidatos).
func total_pares() -> int:
	return _pares.size()


## Pares com veredito já calculado na reavaliação corrente (SC-011: 100%
## dos pares relevantes avaliados dentro do intervalo periódico).
func pares_avaliados() -> int:
	return _vereditos.size()


## Valida um nascimento contra os ativos vigentes (FR-028–FR-031, contrato
## contracts/spawn_validation.md). Devolve `{aceito, x, y, adiar}`:
## 1. folga < `traffic_min_separation` nos DOIS eixos → nasceria sobreposto
##    (FR-031, SC-010) → recusa;
## 2. mesma trajetória a menos de `npc_spawn_safety_distance` → recusa
##    (FR-028);
## 3. encontro dentro da janela de atividade conjunta (mesma regra da R1 da
##    US2) → recusa; encontro que só ocorreria APÓS o descarte de um dos
##    dois → segue aceito (FR-030, SC-010).
##
## `bounds` é a faixa trafegável na altura de criação exigida pela interface
## do contrato; garantir que `(x, y)` está dentro dela é responsabilidade do
## chamador (TrafficManager), então as regras aqui não a consultam. `adiar`
## nasce sempre falso: o adiamento (FR-029) é do chamador, que o decide ao
## esgotar a faixa pretendida e as alternativas — a validação só recusa ou
## aceita UMA posição.
func validar_spawn(categoria: TrafficData, x: float, y: float, bounds: Dictionary) -> Dictionary:
	var recusa := {"aceito": false, "x": x, "y": y, "adiar": false}
	var candidata := _hitbox_da(categoria, Vector2(x, y))
	for npc in _ativos_validacao:
		if npc == null or not npc.is_active():
			continue
		var caixa: Rect2 = npc_hitbox(npc)
		var folga_x: float = (
			absf(caixa.get_center().x - candidata.get_center().x)
			- (caixa.size.x + candidata.size.x) * 0.5
		)
		var folga_y: float = (
			absf(caixa.get_center().y - candidata.get_center().y)
			- (caixa.size.y + candidata.size.y) * 0.5
		)
		# Regra 1 — conflito imediato (FR-031, SC-010).
		if (
			folga_x < GameConfig.traffic_min_separation
			and folga_y < GameConfig.traffic_min_separation
		):
			return recusa
		# Sem projeção lateral não há regras 2 e 3 (FR-006).
		if not _projetam_sobre(candidata, caixa):
			continue
		# Regra 2 — distância de segurança na mesma trajetória (FR-028).
		if folga_y < GameConfig.npc_spawn_safety_distance:
			return recusa
		# Regra 3 — futuro pela janela de atividade (FR-030).
		if _conflito_na_janela(categoria, y, candidata, npc, caixa):
			return recusa
	return {"aceito": true, "x": x, "y": y, "adiar": false}


## Hitbox que um nascimento da categoria ocuparia em `pos` (FR-010) — a
## mesma régua da `npc_hitbox`, sem instanciar o veículo. Sem hitbox
## configurada, cai na dimensão medida do asset (fallback da `npc_hitbox`).
func _hitbox_da(categoria: TrafficData, pos: Vector2) -> Rect2:
	var dim: Vector2 = GameConfig.NPC_HITBOX_SIZES.get(categoria.id, Vector2.ZERO)
	if dim == Vector2.ZERO:
		dim = categoria.size
	return Rect2(pos - dim * 0.5, dim)


## Regra 3 — o encontro da candidata com `npc` cabe na janela de atividade
## conjunta? Mesma estrutura da `_potencial` (FR-002–FR-005, R1), com a
## candidata como veículo virtual: velocidade da categoria e descarte
## calculado pelo `_tempo_descarte_em` (nasce agora, nunca visto).
func _conflito_na_janela(
	categoria: TrafficData, y: float, candidata: Rect2, npc: TrafficVehicle, caixa: Rect2
) -> bool:
	var cand_traseiro: bool = y >= npc.position.y
	var caixa_traseiro: Rect2 = candidata if cand_traseiro else caixa
	var caixa_dianteiro: Rect2 = caixa if cand_traseiro else candidata
	var vel_traseiro: float = categoria.max_speed if cand_traseiro else npc.get_speed()
	var vel_dianteiro: float = npc.get_speed() if cand_traseiro else categoria.max_speed
	var diferenca: float
	if classificar(candidata, caixa) == NpcCollisionData.Tipo.LATERAL:
		diferenca = absf(vel_traseiro - vel_dianteiro)
	else:
		diferenca = vel_traseiro - vel_dianteiro
	# FR-002: sem aproximação relevante não há o que prever.
	if diferenca <= GameConfig.npc_min_relative_speed:
		return false
	var distancia: float = maxf(_distancia_longitudinal(caixa_traseiro, caixa_dianteiro), 0.0)
	var ttc: float = distancia / diferenca
	var t_candidata: float = _tempo_descarte_em(
		categoria.max_speed, y, false, y, candidata.size.y * 0.5
	)
	var janela: float = minf(
		minf(_tempo_descarte(npc), t_candidata),
		GameConfig.npc_collision_prediction_horizon,
	)
	return ttc <= janela


## Reavaliação periódica (FR-008): a cada `npc_reevaluation_interval` os
## vereditos são recalculados com as posições/velocidades correntes — sem
## varrer pares por quadro.
func _reavaliar_periodico(delta: float) -> void:
	_tempo_reavaliacao -= delta
	if _tempo_reavaliacao > 0.0:
		return
	_tempo_reavaliacao = GameConfig.npc_reevaluation_interval
	avaliar_pares()


## Regra da janela de atividade conjunta para o par (FR-002–FR-006, R1):
## mesma trajetória lateral, diferença de velocidade acima do limiar e ttc
## dentro da janela. Calculada AO VIVO — é o que o contato consulta em cada
## momento (FR-035). O jogador não é parâmetro de nada aqui (FR-009).
func _potencial(a: TrafficVehicle, b: TrafficVehicle) -> bool:
	var caixa_a: Rect2 = npc_hitbox(a)
	var caixa_b: Rect2 = npc_hitbox(b)

	# FR-006: projeções laterais sem sobreposição → trajetórias distintas,
	# nunca há previsão nem colisão, mesmo com diferença de velocidade.
	if not _projetam_sobre(caixa_a, caixa_b):
		return false

	var a_traseiro: bool = a.position.y >= b.position.y
	var caixa_traseiro: Rect2 = caixa_a if a_traseiro else caixa_b
	var caixa_dianteiro: Rect2 = caixa_b if a_traseiro else caixa_a
	var traseiro: TrafficVehicle = a if a_traseiro else b
	var dianteiro: TrafficVehicle = b if a_traseiro else a

	# FR-002 / R1: sem aproximação relevante não há o que prever. Em contato
	# LATERAL não existe ordem traseiro/dianteiro (o y pode empatar): o
	# módulo da diferença mantém o veredito insensível à ordem do par — o
	# mesmo espírito da chave canônica (data-model §5).
	var diferenca: float
	if classificar(caixa_a, caixa_b) == NpcCollisionData.Tipo.LATERAL:
		diferenca = absf(a.get_speed() - b.get_speed())
	else:
		diferenca = traseiro.get_speed() - dianteiro.get_speed()
	if diferenca <= GameConfig.npc_min_relative_speed:
		return false

	# FR-003: ttc = distância longitudinal ÷ diferença; já sobrepostos a
	# distância é 0 → o encontro é agora (sempre dentro da janela).
	var distancia: float = maxf(_distancia_longitudinal(caixa_traseiro, caixa_dianteiro), 0.0)
	var ttc: float = distancia / diferenca
	return ttc <= _janela_atividade(traseiro, dianteiro)


## Janela de atividade conjunta (FR-004, R1): o MENOR tempo até o descarte
## dos dois veículos, acrescido da margem da área ativa (em `_tempo_descarte`)
## e limitado ao horizonte configurado. Cobertura dos dois lados resolve o
## falso positivo (encontro pós-descarte) e o falso negativo (FR-005).
func _janela_atividade(a: TrafficVehicle, b: TrafficVehicle) -> float:
	return minf(minf(_tempo_descarte(a), _tempo_descarte(b)),
		GameConfig.npc_collision_prediction_horizon)


## Tempo até o descarte/reciclagem de um veículo (FR-004): a distância até a
## borda da área visível pela qual ele sairia, com `npc_active_area_margin`,
## dividida pela velocidade APARENTE na tela (road − veículo — o mesmo dy do
## SPEC-004). Estacionário na tela → sairia só se o mundo mudasse → tempo
## infinito, resolvido pelo cap do horizonte. Mesmos critérios de
## `_saiu_da_vista` no TrafficManager: quem desce sai pela base; quem sobe
## sai pelo ponto de nascimento (não visto) ou pelo topo (já visto).
func _tempo_descarte(npc: TrafficVehicle) -> float:
	var meia_altura: float = npc.category.size.y * 0.5 if npc.category != null else 0.0
	return _tempo_descarte_em(
		npc.get_speed(), npc.position.y, npc.ja_visto, npc.y_nascimento, meia_altura
	)


## Mesmo cálculo parametrizado — usado pelo `validar_spawn` para a candidata
## ainda NÃO criada: ela nasce agora (`ja_visto == false`,
## `y_nascimento == y`), medida pela hitbox (FR-010), e para o ativo evita
## reconstruir o veículo só para ler cinco campos.
func _tempo_descarte_em(
	velocidade: float, y: float, ja_visto: bool, y_nascimento: float, meia_altura: float
) -> float:
	var aparente: float = _velocidade_estrada - velocidade
	if is_zero_approx(aparente):
		return INF
	var distancia: float
	if aparente > 0.0:
		distancia = TrafficManager.VIEWPORT_HEIGHT + meia_altura - y
	else:
		var y_descarte: float = -meia_altura if ja_visto else y_nascimento
		distancia = y - y_descarte
	distancia = maxf(distancia + GameConfig.npc_active_area_margin, 0.0)
	return distancia / absf(aparente)


## Projeções laterais das hitboxes sobrepostas = mesma trajetória (FR-006).
static func _projetam_sobre(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x


## Distância (px) da traseira do dianteiro até a dianteira do traseiro;
## negativa quando já sobrepostos (o encontro é no presente, ttc = 0).
static func _distancia_longitudinal(caixa_traseiro: Rect2, caixa_dianteiro: Rect2) -> float:
	return caixa_traseiro.position.y - caixa_dianteiro.end.y


## Ponto único de consequência de um NOVO episódio de contato (latch recém
## armado, cooldown livre).
##
## Classifica o contato, identifica causador/atingido, decide alvo e direção
## pelo fallback de borda, resolve a cadeia (bloqueio → sem evento nem
## consequência, FR-027), aplica o drift SOMENTE no alvo com força/duração
## interpoladas pela intensidade e emite o evento com os 7 campos
## (FR-011–FR-016, FR-041). Devolve true apenas quando o impacto foi
## PROCESSADO — o `update` arma latch em qualquer chamada e cooldown só
## quando true.
##
## Não existe neste método — nem em nenhum outro do sistema — caminho de
## escrita em velocidade (FR-017, research R10).
func _processar_novo_contato(
	a: TrafficVehicle, b: TrafficVehicle, caixa_a: Rect2, caixa_b: Rect2
) -> bool:
	var tipo: int = classificar(caixa_a, caixa_b)
	var causador: TrafficVehicle = a
	var atingido: TrafficVehicle = b

	if tipo == NpcCollisionData.Tipo.LONGITUDINAL:
		# Quem alcança a traseira do outro (y maior) é o causador (FR-013, R2).
		var dy: float = caixa_a.get_center().y - caixa_b.get_center().y
		if dy < 0.0:
			causador = b
			atingido = a
		elif dy == 0.0:
			# Empate geométrico: a identidade decide, nunca aleatoriedade (R9).
			if a.get_instance_id() < b.get_instance_id():
				causador = b
				atingido = a
	else:
		# Lateral: quem está DESLOCANDO lateralmente invadiu a coluna do
		# vizinho — drifte ou ultrapassagem em curso marca o invasor (R2,
		# "o veículo cujo deslocamento lateral invadiu a coluna"). Empate
		# (nenhum ou ambos deslocando) → maior instance_id: estável e sem
		# aleatoriedade (R9).
		var a_invade: bool = a.npc_drift.ativo() or a.overtake.ativo()
		var b_invade: bool = b.npc_drift.ativo() or b.overtake.ativo()
		if (a_invade != b_invade and b_invade) or (
			a_invade == b_invade and b.get_instance_id() > a.get_instance_id()
		):
			causador = b
			atingido = a

	var bounds: Dictionary = _bounds_for_y.call(atingido.position.y)
	var dir: int = direcao_drift(atingido, causador, bounds)
	var inten: float = intensidade(a, b)
	var forca: float = lerpf(
		GameConfig.npc_drift_force_min, GameConfig.npc_drift_force_max, inten
	)
	var duracao: float = lerpf(
		GameConfig.npc_drift_duration_min, GameConfig.npc_drift_duration_max, inten
	)

	# FR-019 / R3: fallback de borda decide alvo e direção EFETIVAS antes de
	# aplicar — normal, inversão para o lado oposto ou transferência ao
	# causador (SC-006/SC-007).
	var plano: Dictionary = _resolver_borda(atingido, causador, dir, forca, duracao, bounds)
	var alvo: TrafficVehicle = plano.alvo
	var direcao_efetiva: int = plano.direcao

	# FR-024/FR-025: a cadeia decide se este impacto é processado. Bloqueio
	# (profundidade máxima ou atingido já processado) → SEM evento e SEM
	# consequência (FR-027); devolve false para o update não armar latch nem
	# cooldown — o par segue testado quadro a quadro.
	var cadeia: NpcChainState = _resolver_cadeia(causador, atingido)
	if cadeia == null:
		return false

	# Consequência exclusivamente lateral no alvo do drift (FR-014/FR-016):
	# novo impacto SUBSTITUI o drift em curso (Clarificação Q4). O outro
	# veículo não recebe nada e nenhum dos dois tem velocidade tocada
	# (FR-017, Q2).
	alvo.aplicar_drift_npc(direcao_efetiva, forca, duracao, cadeia.id, cadeia.profundidade_atual)
	# FR-033 / R8: início do deslocamento lateral → a posição do corredor
	# vai mudar → reconstrói o cache dos pares.
	marcar_reavaliacao()

	var data := NpcCollisionData.new()
	data.causador = causador
	data.atingido = atingido
	data.tipo = tipo
	data.intensidade = inten
	data.direcao_drift = direcao_efetiva
	data.cadeia_id = alvo.npc_drift.cadeia_id
	data.profundidade = alvo.npc_drift.profundidade
	npc_collision_occurred.emit(data)
	return true


## Hitbox do NPC pela categoria configurada (FR-010); fallback na área
## ocupada declarada pelo trânsito quando a categoria não tem hitbox própria
## — nenhum segundo conjunto de hitboxes (contrato §1, Assumptions).
func npc_hitbox(npc: TrafficVehicle) -> Rect2:
	var dim: Vector2 = GameConfig.NPC_HITBOX_SIZES.get(npc.get_category_id(), Vector2.ZERO)
	return Rect2(npc.position - dim * 0.5, dim) if dim != Vector2.ZERO else npc.get_occupied_area()


## Classificação pelo eixo de menor penetração (FR-011, R2): penetração
## horizontal menor → LATERAL; vertical menor → LONGITUDINAL. Mesma convenção
## da SPEC-005, com um tipo a menos (o jogador não participa).
func classificar(caixa_a: Rect2, caixa_b: Rect2) -> int:
	var ox: float = _penetracao(
		caixa_a.position.x, caixa_a.end.x, caixa_b.position.x, caixa_b.end.x
	)
	var oy: float = _penetracao(
		caixa_a.position.y, caixa_a.end.y, caixa_b.position.y, caixa_b.end.y
	)
	if ox <= oy:
		return NpcCollisionData.Tipo.LATERAL
	return NpcCollisionData.Tipo.LONGITUDINAL


static func _penetracao(a_min: float, a_max: float, b_min: float, b_max: float) -> float:
	return minf(a_max, b_max) - maxf(a_min, b_min)


## Intensidade do impacto (FR-012): velocidade relativa entre os dois,
## normalizada pelo mesmo divisor da SPEC-005 e clampada em [0, 1] — mesma
## convenção de interpolação de força/duração.
func intensidade(a: TrafficVehicle, b: TrafficVehicle) -> float:
	var relativa: float = absf(a.get_speed() - b.get_speed())
	return clampf(relativa / GameConfig.collision_intensity_divisor, 0.0, 1.0)


## Direção do drift (FR-015, R2): lado oposto ao impacto pela posição
## relativa; dentro da margem neutra, o lado com mais espaço trafegável NA
## ALTURA do atingido; empate de espaço → esquerda, sempre a mesma resposta
## para o mesmo cenário.
func direcao_drift(atingido: TrafficVehicle, causador: TrafficVehicle, bounds: Dictionary) -> int:
	var dx: float = atingido.position.x - causador.position.x
	if absf(dx) > GameConfig.npc_relative_position_threshold:
		return int(signf(dx))
	var espaco_dir: float = float(bounds.right) - atingido.position.x
	var espaco_esq: float = atingido.position.x - float(bounds.left)
	return 1 if espaco_dir > espaco_esq else -1


## Fallback de borda (FR-019, research R3) — devolve `{alvo, direcao}` do
## drift ANTES de aplicar:
## - cabe na direção normal → normal;
## - não cabe mas o atingido está longe da borda (`npc_border_margin`) →
##   normal mesmo assim: o clamp por quadro do próprio drift resolve (FR-018);
## - perto da borda e cabe do lado oposto → INVERTE (SC-006);
## - nenhum lado comporta → TRANSFERE o deslocamento ao causador com a
##   direção invertida, também clampado pelos limites dele — o único caminho
##   que mantém "ninguém sai da pista" num corredor estreito (SC-007).
##
## `previsto` é a integral da força decaindo linearmente sobre a duração
## (forca × duração ÷ 2), truncada no teto de deslocamento (FR-020).
func _resolver_borda(
	atingido: TrafficVehicle,
	causador: TrafficVehicle,
	dir: int,
	forca: float,
	duracao: float,
	bounds: Dictionary
) -> Dictionary:
	var meia: float = atingido.category.size.x * 0.5 if atingido.category != null else 0.0
	var esquerda: float = float(bounds.left)
	var direita: float = float(bounds.right)
	var limite_esq: float = esquerda + meia
	var limite_dir: float = direita - meia
	if limite_dir < limite_esq:
		# Pista mais estreita que o veículo: centraliza (mesma regra de
		# _atualizar_drifts e _reaplicar_limite).
		limite_esq = (esquerda + direita) * 0.5
		limite_dir = limite_esq

	var previsto: float = minf(forca * duracao * 0.5, GameConfig.npc_displacement_limit)
	var espaco_normal: float = (
		limite_dir - atingido.position.x if dir > 0 else atingido.position.x - limite_esq
	)
	if espaco_normal >= previsto:
		return {"alvo": atingido, "direcao": dir}
	if espaco_normal > GameConfig.npc_border_margin:
		return {"alvo": atingido, "direcao": dir}

	var espaco_oposto: float = (
		atingido.position.x - limite_esq if dir > 0 else limite_dir - atingido.position.x
	)
	if espaco_oposto >= previsto:
		return {"alvo": atingido, "direcao": -dir}
	return {"alvo": causador, "direcao": -dir}


## T029 — avança os cronômetros das cadeias por quadro (0,167 s por tick);
## sem alocação, só mutação dos objetos já existentes (FR-045).
func _avancar_cadeias(delta: float) -> void:
	for id in _cadeias:
		_cadeias[id].avancar(delta)


## Varre cadeias vencidas — chamada APENAS na criação de uma cadeia nova
## (event-driven): quando nada muda, o custo por quadro é só o dos tickers
## vivos (FR-045, research R4).
func _limpar_expiradas() -> void:
	if _cadeias.is_empty():
		return
	var vivas: Dictionary = {}
	for id in _cadeias:
		if not _cadeias[id].expirada():
			vivas[id] = _cadeias[id]
	_cadeias = vivas


## T032 — decrementa o cooldown de cada par ativo por quadro (R5: contador
## por objeto no sistema, nunca memória do veículo). Pares intocados nem
## aparecem no dicionário.
func _decrementar_cooldowns(delta: float) -> void:
	for chave in _cooldowns:
		_cooldowns[chave] = maxf(_cooldowns[chave] - delta, 0.0)


## T030/T031 — resolve a cadeia do impacto (FR-024, FR-025, R4, CA1–CA8).
## Devolve `null` quando o impacto é BLOQUEADO (sem evento e sem
## consequência, FR-027):
## - ELO: o causador é ex-atingido com drift ativo carregando cadeia viva →
##   herda, soma profundidade e registra os dois participantes. Teto de
##   profundidade estourado ou atingido já processado pela MESMA cadeia →
##   bloqueado (FR-025, SC-008 = 0 loops).
## - SEM ELO (causador sem drift, drift sem cadeia ou cadeia expirada):
##   cadeia PRÓPRIA nova com id monotônico — colisões paralelas nunca herdam
##   entre si por proximidade no tempo (Clarificação Q5, CA8).
func _resolver_cadeia(causador: TrafficVehicle, atingido: TrafficVehicle) -> NpcChainState:
	if causador.npc_drift.ativo() and causador.npc_drift.cadeia_id != 0:
		var cadeia: NpcChainState = _cadeias.get(causador.npc_drift.cadeia_id)
		if cadeia != null and not cadeia.expirada():
			if not cadeia.pode_avancar():
				return null
			if cadeia.ja_processado(atingido.get_instance_id()):
				return null
			cadeia.profundidade_atual += 1
			cadeia.registrar(causador.get_instance_id())
			cadeia.registrar(atingido.get_instance_id())
			return cadeia

	_limpar_expiradas()
	var nova := NpcChainState.new(_proximo_id_cadeia)
	_proximo_id_cadeia += 1
	nova.registrar(causador.get_instance_id())
	nova.registrar(atingido.get_instance_id())
	_cadeias[nova.id] = nova
	return nova


## Avança o drift lateral de cada veículo com drift ativo, consultando os
## limites NA ALTURA do veículo a cada quadro (FR-018, FR-040 — nunca largura
## memorizada). A meia-largura é descontada aqui para que o clamp do drift
## respeite a área ocupada completa; sem drift, o método nem é chamado
## (aditividade, SC-016).
func _atualizar_drifts(delta: float, npcs: Array, bounds_for_y: Callable) -> void:
	for npc in npcs:
		if npc == null or not npc.is_active() or not npc.npc_drift.ativo():
			continue
		var bounds: Dictionary = bounds_for_y.call(npc.position.y)
		var esquerda: float = float(bounds.left)
		var direita: float = float(bounds.right)
		var meia_largura: float = npc.category.size.x * 0.5 if npc.category != null else 0.0
		var limite_esq: float = esquerda + meia_largura
		var limite_dir: float = direita - meia_largura
		if limite_dir < limite_esq:
			# Pista mais estreita que o veículo: centraliza (mesma regra de
			# _reaplicar_limite no TrafficVehicle).
			limite_esq = (esquerda + direita) * 0.5
			limite_dir = limite_esq
		npc.atualizar_drift_npc(delta, limite_esq, limite_dir)
		if not npc.npc_drift.ativo():
			# FR-033 / R8: fim do deslocamento lateral → posição final da
			# faixa mudou → reconstrói o cache. `_revalidar_cache` roda mais
			# adiante no MESMO quadro, então o rebuild não espera o próximo.
			marcar_reavaliacao()


## Revalida o cache: reconstrói quando o conjunto de ativos mudou (spawn,
## reciclagem) ou sob bandeira explícita. A geometria dos pares (sobreposição,
## distância) é recalculada por quadro no laço do `update` — o cache guarda
## apenas a COMPOSIÇÃO dos pares, que é o que muda com o pool (data-model §1).
func _revalidar_cache(npcs: Array) -> void:
	var atuais: Dictionary = {}
	for npc in npcs:
		if npc != null and npc.is_active():
			atuais[npc.get_instance_id()] = true

	var mudou: bool = _pares_sujos
	if not mudou:
		if atuais.size() != _ids_construcao.size():
			mudou = true
		else:
			for id in atuais:
				if not _ids_construcao.has(id):
					mudou = true
					break
	if not mudou:
		return

	_construir_pares(npcs, atuais)
	_pares_sujos = false


## Reconstrói a lista de pares na ordem determinística de processamento:
## ativos ordenados por (y, instance_id) e pares i<j nessa ordem — decisões
## estáveis mesmo com três ou mais NPCs sobrepostos (research R9, Edge Case).
## A chave é o par canônico min:max, ordem-insensível (data-model §5).
func _construir_pares(npcs: Array, ids: Dictionary) -> void:
	_pares.clear()
	_vereditos.clear()  # par saiu do pool → veredito dele não vale mais (FR-008)
	_ids_construcao = ids

	var ativos: Array = []
	for npc in npcs:
		if npc != null and npc.is_active():
			ativos.append(npc)
	ativos.sort_custom(_ordenar_candidatos)

	for i in range(ativos.size()):
		for j in range(i + 1, ativos.size()):
			var a: TrafficVehicle = ativos[i]
			var b: TrafficVehicle = ativos[j]
			_pares.append({
				"chave": chave_par(a.get_instance_id(), b.get_instance_id()),
				"a": a,
				"b": b,
			})


## Chave canônica do par: `"minId:maxId"` (ordem-insensível, única por dupla).
static func chave_par(id_um: int, id_dois: int) -> String:
	return "%d:%d" % [mini(id_um, id_dois), maxi(id_um, id_dois)]


## Ordenação determinística de pares: y crescente (mais acima primeiro) e
## instance_id como desempate — sempre a mesma ordem para o mesmo cenário.
static func _ordenar_candidatos(a: TrafficVehicle, b: TrafficVehicle) -> bool:
	if a.position.y != b.position.y:
		return a.position.y < b.position.y
	return a.get_instance_id() < b.get_instance_id()
