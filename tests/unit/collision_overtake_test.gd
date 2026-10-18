extends GdUnitTestSuite

## SPEC-005 / T023 — colisão tipo 1-3 (NPC atinge a traseira do jogador):
## velocidade do NPC inalterada (FR-017, SC-006), deslocamento lateral para o
## lado oposto ao drift do jogador (FR-018), ultrapassagem concluída em pista
## livre (FR-019, critério objetivo da Clarification 2026-10-05), clamp nos
## limites vigentes (FR-020, SC-007) e retorno à trajetória normal (FR-021).

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}

var sistema: CollisionSystem
var jogador: PlayerVehicle


func before_test() -> void:
	sistema = CollisionSystem.new()
	jogador = PlayerVehicle.new()
	jogador.position = Vector2(320.0, 400.0)


func after_test() -> void:
	jogador.free()
	sistema = null


func _npc(pos: Vector2, categoria_id: String = "esporte") -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = Vector2(32.0, 48.0)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	# Igual ao limite fixo dos testes → "faixa estável", sem reposicionamento.
	npc.previous_right_boundary = float(BOUNDS_FIXOS.right)
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


func _quadros_npc(npc: TrafficVehicle, n: int, road_speed: float = 20.0) -> void:
	for i in n:
		npc.update_scroll(1.0 / 60.0, road_speed, BOUNDS_FIXOS, INF)


## Cenário principal (US3-CA2): jogador à frente, mais lento e à direita do NPC.
## O jogador sofre drift +1; o NPC desloca -1 e ultrapassa pela esquerda.
func test_npc_speed_unchanged_and_overtakes_on_opposite_side() -> void:
	jogador.controller.speed = 30.0
	jogador.position.x = 332.0
	var npc := _npc(Vector2(320.0, 436.0))  # atrás do jogador (y maior), mais rápido
	var velocidade_antes := npc.get_speed()

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_int(eventos.size()).is_equal(1)
	assert_int(eventos[0].tipo).is_equal(CollisionData.CollisionType.NPC_HITS_PLAYER_REAR)
	assert_int(eventos[0].direcao_drift).is_equal(1)
	assert_float(npc.get_speed()).is_equal(velocidade_antes).override_failure_message(
		"FR-017/SC-006: velocidade do NPC alterada pela colisão"
	)
	assert_bool(npc.overtake.ativo()).is_true().override_failure_message(
		"FR-018: NPC não recebeu deslocamento de ultrapassagem"
	)

	# 1,0 s de quadros: fase de IDA concluída (magnitude completa) e NPC mais
	# rápido já subiu — critérios objetivos da FR-019 medidos aqui.
	_quadros_npc(npc, 60)
	var caixa_jogador := sistema.player_hitbox(jogador)
	var caixa_npc := sistema.npc_hitbox(npc)
	assert_bool(caixa_jogador.intersects(caixa_npc)).is_false().override_failure_message(
		"FR-019: hitboxes ainda sobrepostas ao fim da IDA do deslocamento"
	)
	assert_float(npc.position.x).is_less(320.0).override_failure_message(
		"FR-018: NPC não deslocou para o lado oposto ao drift do jogador"
	)
	assert_bool(npc.position.y < jogador.position.y).override_failure_message(
		"FR-019/SC-006: NPC não terminou à frente do jogador (ultrapassagem incompleta)"
	)
	assert_bool(npc.overtake.em_retorno()).is_true().override_failure_message(
		"FR-021: após a IDA o NPC não iniciou o retorno à faixa de origem"
	)

	# +2,0 s: retorno (1,0 s) concluído — NPC ocupa exatamente a faixa de
	# origem e o estado termina, sem deslocamento lateral permanente (FR-021).
	_quadros_npc(npc, 120)
	assert_bool(npc.overtake.ativo()).is_false().override_failure_message(
		"FR-021: deslocamento não encerrou; NPC ficou com drift permanente"
	)
	assert_float(npc.position.x).is_equal_approx(320.0, 0.1).override_failure_message(
		"FR-021: NPC não voltou à faixa de origem (x=%.2f, esperado 320)" % npc.position.x
	)
	npc.free()


## Ajuste 6 / FR-021 — após a IDA, o NPC retorna à faixa de origem e o estado
## encerra; sem isso ele permanecia deslocado, invadindo o corredor de outra
## velocidade e fazendo o limitador acoplar categorias (caminhões em taxa de
## passeio depois de colisões).
func test_overtake_returns_to_original_lane() -> void:
	var npc := _npc(Vector2(320.0, 200.0))
	npc.apply_overtake_offset(1, GameConfig.npc_overtake_magnitude, GameConfig.npc_overtake_duration)

	_quadros_npc(npc, 60)  # IDA de 1,0 s
	assert_bool(npc.overtake.em_retorno()).is_true().override_failure_message(
		"FR-021: IDA não mudou para a fase de retorno"
	)
	assert_float(npc.position.x).is_greater(320.0).override_failure_message(
		"FR-018: NPC não deslocou para a direita na IDA"
	)

	_quadros_npc(npc, 70)  # RETORNO de 1,0 s (folga para o passo final)
	assert_bool(npc.overtake.ativo()).is_false().override_failure_message(
		"FR-021: retorno não concluiu dentro da duração configurada"
	)
	assert_float(npc.position.x).is_equal_approx(320.0, 0.1).override_failure_message(
		"FR-021: NPC terminou em x=%.2f e não na faixa de origem (320)" % npc.position.x
	)
	npc.free()


## Ajuste 6 / FR-021 + Edge Case "colado à borda" — quando a IDA trava no
## limite da pista (não atinge a magnitude), o retorno ainda leva o NPC de
## volta ao x de origem.
func test_overtake_clamped_out_still_returns_to_lane() -> void:
	var npc := _npc(Vector2(374.0, 200.0))  # limite direito 392 - meia 16 = 376
	npc.apply_overtake_offset(1, GameConfig.npc_overtake_magnitude, GameConfig.npc_overtake_duration)

	_quadros_npc(npc, 60)  # IDA trava em 376 (só 2 px disponíveis)
	assert_bool(npc.overtake.em_retorno()).is_true().override_failure_message(
		"FR-021: IDA travada na borda não mudou para a fase de retorno"
	)
	assert_float(npc.position.x).is_equal_approx(376.0, 0.5).override_failure_message(
		"FR-020: NPC ultrapassou o limite direito na IDA (x=%.2f)" % npc.position.x
	)

	_quadros_npc(npc, 70)
	assert_bool(npc.overtake.ativo()).is_false().override_failure_message(
		"FR-021: retorno da borda não concluiu"
	)
	assert_float(npc.position.x).is_equal_approx(374.0, 0.1).override_failure_message(
		"FR-021: NPC não voltou ao x de origem após travar na borda (x=%.2f)" % npc.position.x
	)
	npc.free()


## Sem espaço lateral na direção do deslocamento: para no limite (FR-020,
## Edge Case "colado à borda"). O estado é injetado direto — a regra de
## direção já está coberta pelo cenário principal.
func test_overtake_clamped_at_road_limit() -> void:
	var npc := _npc(Vector2(266.0, 200.0))  # quase na borda esquerda
	var meia_largura: float = npc.category.size.x * 0.5
	npc.apply_overtake_offset(-1, GameConfig.npc_overtake_magnitude, GameConfig.npc_overtake_duration)
	_quadros_npc(npc, 120)
	assert_float(npc.position.x).is_greater_equal(float(BOUNDS_FIXOS.left) + meia_largura - 0.01).override_failure_message(
		"FR-020/SC-007: deslocamento do NPC ultrapassou o limite esquerdo"
	)
	npc.free()


## T047 / FR-020, FR-023, SC-007, US3-CA4: durante a REDUÇÃO de pista o limite
## direito estreita por quadro; o deslocamento de ultrapassagem do NPC deve
## permanecer dentro do limite vigente em cada altura, sem largura memorizada.
func test_overtake_respects_narrowing_transition_boundaries() -> void:
	var npc := _npc(Vector2(320.0, 200.0))
	var meia_largura: float = npc.category.size.x * 0.5
	npc.apply_overtake_offset(1, GameConfig.npc_overtake_magnitude, GameConfig.npc_overtake_duration)

	var direita := 424.0  # 4 vias → estreitando para 392 (2 vias)
	var violou := false
	var menor_direita := direita
	for i in 120:
		direita = maxf(direita - 0.3, 392.0)
		menor_direita = direita
		npc.previous_right_boundary = direita  # faixa "estável" do ponto de vista do reposicionamento
		npc.update_scroll(1.0 / 60.0, 20.0, {"left": 248.0, "right": direita}, INF)
		if npc.position.x > direita - meia_largura + 0.01:
			violou = true

	assert_bool(violou).is_false().override_failure_message(
		"SC-007: ultrapassagem do NPC ultrapassou o limite direito vigente durante a transição"
	)
	assert_bool(menor_direita == 392.0)  # a transição realmente estreitou durante o teste
	npc.free()
