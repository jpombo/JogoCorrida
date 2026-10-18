extends GdUnitTestSuite

## SPEC-006 / T015 — previsão e janela de atividade (SC-001–SC-003,
## FR-002–FR-006): Cenário 1 (encontro curto dentro da área ativa) →
## potencial em 100%; Cenário 2 (encontro só após o descarte de um dos dois)
## → 0 previsões; mesma velocidade → 0; trajetórias distintas → 0; e a
## presença do jogador entre os dois não altera a avaliação (FR-009, T019).
##
## T046 (US8, SC-012/SC-013): variação relevante da velocidade do jogador
## dispara reavaliação imediata; mantida a velocidade, nenhuma reavaliação
## nova; a reavaliação nunca registra colisão sem a regra da janela.

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}

var sistema: NpcCollisionSystem
## Intervalo original salvo para os testes que congelam o periódico — o
## after_test restaura mesmo quando a asserção aborta o teste.
var _intervalo_original: float


func before_test() -> void:
	sistema = NpcCollisionSystem.new()
	_intervalo_original = GameConfig.npc_reevaluation_interval


func after_test() -> void:
	GameConfig.npc_reevaluation_interval = _intervalo_original
	sistema = null


## `y_nascimento` −200 simula o nascimento acima do topo (FR-013): com a
## estrada parada o veículo sobe e só é descartado ao cruzar esse ponto.
func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = GameConfig.NPC_HITBOX_SIZES[categoria_id]
	npc.position = pos
	npc.y_nascimento = -200.0
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


func _avaliar(npcs: Array) -> void:
	sistema.update(1.0 / 60.0, npcs, _bounds)


func test_cenario_1_encontro_curto_dentro_da_janela_e_potencial() -> void:
	# Esporte (96) atrás do caminhão (72) a 9 px — ttc ≈ 0,4 s ≤ janela.
	var caminhao := _npc("caminhao", Vector2(320.0, 100.0))
	var esporte := _npc("esporte", Vector2(320.0, 160.0))
	_avaliar([caminhao, esporte])

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_true().override_failure_message(
		"SC-001 Cenário 1: encontro curto na área ativa não é potencial"
	)
	caminhao.free()
	esporte.free()


func test_cenario_2_encontro_pos_descarte_nao_e_potencial() -> void:
	# Mesmo par com ttc ≈ 15 s — muito além da janela de atividade conjunta
	# (o caminhão seria descartado em ~3,9 s): falso positivo proibido (FR-005).
	var caminhao := _npc("caminhao", Vector2(320.0, 40.0))
	var esporte := _npc("esporte", Vector2(320.0, 460.0))
	_avaliar([caminhao, esporte])

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_false().override_failure_message(
		"SC-001 Cenário 2: encontro pós-descarte gerou previsão (falso positivo)"
	)
	caminhao.free()
	esporte.free()


func test_mesma_velocidade_nao_gera_previsao() -> void:
	# FR-002: diferença ≤ npc_min_relative_speed → sem aproximação relevante.
	var a := _npc("passeio", Vector2(320.0, 100.0))
	var b := _npc("passeio", Vector2(320.0, 160.0))
	_avaliar([a, b])

	assert_bool(sistema.tem_potencial(a, b)).is_false().override_failure_message(
		"FR-002: par de mesma velocidade gerou previsão"
	)
	a.free()
	b.free()


func test_trajetorias_distintas_nao_geram_previsao() -> void:
	# FR-006: projeções laterais sem sobreposição → sem previsão, mesmo com
	# diferença de velocidade.
	var caminhao := _npc("caminhao", Vector2(360.0, 100.0))
	var esporte := _npc("esporte", Vector2(260.0, 160.0))
	_avaliar([caminhao, esporte])

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_false().override_failure_message(
		"FR-006: trajetórias distintas geraram previsão"
	)
	caminhao.free()
	esporte.free()


func test_veredito_e_insensivel_a_ordem_do_par() -> void:
	# Chave canônica (T007/data-model §5): avaliar (a,b) ou (b,a) é o mesmo
	# par — o veredito em cache é único por dupla.
	var caminhao := _npc("caminhao", Vector2(320.0, 100.0))
	var esporte := _npc("esporte", Vector2(320.0, 160.0))
	_avaliar([caminhao, esporte])

	var direto: bool = sistema.tem_potencial(caminhao, esporte)
	var invertido: bool = sistema.tem_potencial(esporte, caminhao)
	assert_bool(direto).is_equal(invertido).override_failure_message(
		"data-model §5: veredito depende da ordem do par"
	)
	caminhao.free()
	esporte.free()


func test_presenca_do_jogador_nao_bloqueia_a_previsao() -> void:
	# FR-009: o jogador entre os dois NPCs não entra em nenhum campo da
	# avaliação — a previsão entre eles permanece a mesma.
	var caminhao := _npc("caminhao", Vector2(320.0, 100.0))
	var esporte := _npc("esporte", Vector2(320.0, 160.0))
	var jogador := PlayerVehicle.new()
	jogador.position = Vector2(320.0, 130.0)  # exatamente entre os dois
	_avaliar([caminhao, esporte])

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_true().override_failure_message(
		"FR-009: presença do jogador entre os NPCs bloqueou a previsão"
	)
	jogador.free()
	caminhao.free()
	esporte.free()


## US8-CA1 / FR-032, FR-034 / SC-013 — formação segura a 100 que vira
## perigosa ao FREAR (100 → 80): o esporte atrás do caminhão estava abaixo
## da área ativa, se afastando (estrada mais rápida que ele → descarte
## imediato → janela 0); com a estrada a 80 ele sobe, alcança o caminhão
## dentro da janela — a reavaliação detecta a nova condição.
func test_frear_dispara_reavaliacao_e_nova_condicao() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 460.0))
	var esporte := _npc("esporte", Vector2(320.0, 551.0))
	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 100.0)

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_false().override_failure_message(
		"SC-013: sanidade — a formação deveria ser segura antes de frear"
	)

	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 80.0)

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_true().override_failure_message(
		"FR-034/SC-013: frear não reavaliou — a formação perigosa não foi detectada"
	)
	caminhao.free()
	esporte.free()


## US8-CA1 / SC-013 — ensaio negativo: a mesma queda de velocidade com o
## esporte a 200 px (ttc ≈ 8,3 s > horizonte de 3,0 s) mantém a
## permanência insuficiente — nenhuma previsão nasce da reavaliação.
func test_frear_sem_janela_suficiente_nao_gera_previsao() -> void:
	var caminhao := _npc("caminhao", Vector2(320.0, 460.0))
	var esporte := _npc("esporte", Vector2(320.0, 711.0))
	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 100.0)
	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 80.0)

	assert_bool(sistema.tem_potencial(caminhao, esporte)).is_false().override_failure_message(
		"SC-013: previsão gerada mesmo com permanência insuficiente"
	)
	caminhao.free()
	esporte.free()


## US8-CA2 / SC-012 — mantida a velocidade do jogador, nenhuma reavaliação
## nova dispara (o periódico é congelado para isolar o gatilho); ao FREAR,
## exatamente uma reavaliação imediata acontece.
func test_velocidade_mantida_nao_dispara_reavaliacao() -> void:
	GameConfig.npc_reevaluation_interval = 10000.0
	var caminhao := _npc("caminhao", Vector2(320.0, 460.0))
	var esporte := _npc("esporte", Vector2(320.0, 551.0))

	# Primeiro quadro: o periódico inicial (timer em zero) reavalia uma vez.
	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 100.0)
	var base: int = sistema.total_reavaliacoes()
	assert_int(base).is_equal(1).override_failure_message(
		"sanidade: o primeiro quadro deve disparar a reavaliação inicial"
	)

	for i in 5:
		sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 100.0)
	assert_int(sistema.total_reavaliacoes()).is_equal(base).override_failure_message(
		"SC-012: reavaliou sem mudança da velocidade do jogador"
	)

	sistema.update(1.0 / 60.0, [caminhao, esporte], _bounds, 80.0)
	assert_int(sistema.total_reavaliacoes()).is_equal(base + 1).override_failure_message(
		"SC-012/FR-032: frear não disparou reavaliação imediata"
	)
	caminhao.free()
	esporte.free()


## US8-CA4 / FR-035 / SC-012 / T049 — par realmente SE SOBREPONDO, mas sem
## a regra da janela (mesma velocidade): nem a reavaliação por variação de
## velocidade nem a explícita registram colisão — só o contato com janela
## satisfeita no momento emite.
func test_reavaliacao_nao_registra_colisao_sem_janela() -> void:
	var eventos: Array = []
	sistema.npc_collision_occurred.connect(func(d): eventos.append(d))
	var a := _npc("passeio", Vector2(320.0, 200.0))
	var b := _npc("passeio", Vector2(320.0, 230.0))  # hitboxes se sobrepõem

	sistema.update(1.0 / 60.0, [a, b], _bounds, 100.0)
	sistema.update(1.0 / 60.0, [a, b], _bounds, 80.0)
	sistema.update(1.0 / 60.0, [a, b], _bounds, 80.0)
	sistema.avaliar_pares()

	assert_int(eventos.size()).is_zero().override_failure_message(
		"FR-035/SC-012: reavaliação registrou colisão sem a regra da janela"
	)
	a.free()
	b.free()
