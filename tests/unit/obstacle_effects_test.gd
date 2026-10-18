extends GdUnitTestSuite

## SPEC-011 / T020 (US3) — Comportamento dos obstáculos após o ajuste do
## aceite T032: POÇA desvia o carro de meio carro pela posição do impacto,
## fica inerte e permanece na pista até sair da tela (sem efeito de
## aderência); CASCALHO limita o teto da velocidade e expira, renovando por
## sobrescrita sem empilhar; `reset()` limpa o efeito; sonda de 100
## encontros por obstáculo em Desafio com 0 atravessamentos
## (FR-014 ajustado/FR-015/FR-016/FR-020, SC-008/SC-009).

var controller: VehicleController
var manager: ObstacleManager
var road: Road
var track: TrackManager
var player: PlayerVehicle
var fuel: FuelSystem

var _scroll_original: float
var _cap_original: float
var _inicial_original: float
var _desvio_original: float
var _acertos: int = 0


func before_test() -> void:
	_acertos = 0
	_scroll_original = GameConfig.scroll_multiplier
	_cap_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_desvio_original = GameConfig.poca_desvio_lateral
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = 100.0
	GameConfig.poca_desvio_lateral = 11.0

	controller = VehicleController.new()
	manager = ObstacleManager.new()
	add_child(manager)
	manager.configurar()
	manager.definir_disponivel(true)
	road = Road.new()
	road.scroll_speed = 400.0 * _scroll_original  # Desafio: 4,0× ⇒ 6,7 px/quadro
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	player = PlayerVehicle.new()
	player.position = Vector2(320.0, 432.0)
	player.controller.speed = 400.0
	fuel = FuelSystem.new()
	fuel.definir_capacidade_derivada(100.0)
	fuel.reset()


func after_test() -> void:
	Input.action_release("move_left")
	Input.action_release("accelerate")
	GameConfig.scroll_multiplier = _scroll_original
	GameConfig.fuel_capacity = _cap_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.poca_desvio_lateral = _desvio_original
	manager.free()
	road.free()
	track.free()
	player.free()
	fuel.free()


func _contar_acerto(_tipo: String = "") -> void:
	_acertos += 1


## Coloca um obstáculo do pool sobre o jogador e atualiza 1 quadro.
func _bater(tipo: String) -> Obstacle:
	var item: Obstacle = manager.pool.pop_back()
	manager.ativos.append(item)
	item.definir_tipo(tipo)
	item.ativar(player.position)
	manager.update(1.0 / 60.0, road, [], track, player)
	return item


## POÇA — centro do carro à esquerda do centro da poça ⇒ desvio para a
## esquerda de exatamente meio carro (11 px).
func test_01_poca_desvia_para_esquerda() -> void:
	player.position = Vector2(320.0, 432.0)
	var item := _bater(Obstacle.TIPO_POCA)
	assert_float(player.position.x).is_equal_approx(320.0 - 11.0, 0.001)
	assert_int(item.estado).is_equal(Obstacle.Estado.ATINGIDO)
	assert_bool(manager.ativos.has(item)).is_true().override_failure_message(
		"Poça desapareceu no impacto — deve permanecer na pista (FR-014 ajustado)"
	)


## POÇA — centro do carro à direita do centro da poça ⇒ desvio para a
## direita de meio carro.
func test_02_poca_desvia_para_direita() -> void:
	player.position = Vector2(320.0, 432.0)
	var item := Obstacle.new()
	add_child(item)
	item.preparar()
	item.definir_tipo(Obstacle.TIPO_POCA)
	manager.ativos.append(item)
	item.ativar(Vector2(290.0, 432.0))  # poça à esquerda do carro ⇒ desvia p/ direita
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_float(player.position.x).is_equal_approx(320.0 + 11.0, 0.001)
	assert_int(item.estado).is_equal(Obstacle.Estado.ATINGIDO)


## POÇA — o desvio nunca joga o carro para fora da pista (clamp nas
## bordas vigentes + meia largura do carro).
func test_03_poca_respeita_borda_da_pista() -> void:
	var esquerda: float = road.left_boundary
	player.position = Vector2(esquerda + 11.0, 432.0)  # encostado na borda
	var item := Obstacle.new()
	add_child(item)
	item.preparar()
	item.definir_tipo(Obstacle.TIPO_POCA)
	manager.ativos.append(item)
	item.ativar(Vector2(esquerda + 30.0, 432.0))  # poça à direita ⇒ desvia p/ esquerda
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_float(player.position.x).is_equal_approx(esquerda + 11.0, 0.001).override_failure_message(
		"Desvio empurrou o carro para fora da pista"
	)


## POÇA — inerte após o 1º hit: reapresentar o carro sobre a mesma poça
## não gera novo desvio (1 único `obstacle_hit`).
func test_04_poca_inerte_apos_primeiro_hit() -> void:
	if not manager.obstacle_hit.is_connected(_contar_acerto):
		manager.obstacle_hit.connect(_contar_acerto)
	player.position = Vector2(320.0, 432.0)
	var item := _bater(Obstacle.TIPO_POCA)
	assert_int(_acertos).is_equal(1)

	# Volta o carro para cima da mesma poça (sobreposição de novo).
	player.position.x = item.position.x
	var x_apos_desvio: float = player.position.x
	manager.update(1.0 / 60.0, road, [], track, player)

	assert_int(_acertos).is_equal(1).override_failure_message(
		"Poça inerte voltou a disparar"
	)
	assert_float(player.position.x).is_equal_approx(x_apos_desvio, 0.001)


## POÇA — permanece visível e ativa na pista até sair da área da tela,
## quando só então é reciclada (nunca some no impacto).
func test_05_poca_permanece_ate_sair_da_tela() -> void:
	player.position = Vector2(320.0, 432.0)
	var item := _bater(Obstacle.TIPO_POCA)
	assert_bool(manager.ativos.has(item)).is_true()
	assert_bool(item.visible).is_true()

	# Segura o jogador de lado e rola até a poça cruzar a base (480 px).
	player.position.x = 1000.0
	var delta: float = 1.0 / 60.0
	var quadros: int = 0
	while manager.ativos.has(item) and quadros < 600:
		manager.update(delta, road, [], track, player)
		quadros += 1

	assert_bool(manager.ativos.has(item)).is_false().override_failure_message(
		"Poça nunca saiu da tela nem foi reciclada"
	)
	assert_bool(manager.pool.has(item)).is_true()


## POÇA — sem efeito de aderência: o fator do veículo continua 1,0 após o
## impacto (o desvio substituiu a redução de aderência — decisão T032).
func test_06_poca_sem_efeito_de_aderencia() -> void:
	player.position = Vector2(320.0, 432.0)
	_bater(Obstacle.TIPO_POCA)
	assert_float(player.controller._fator_aderencia_efetivo()).is_equal_approx(1.0, 0.001)
	assert_float(player.controller.efeito_velocidade_tempo).is_equal(0.0)


## CASCALHO — limita o teto a cada quadro enquanto ativo e o teto normal
## volta sozinho após expirar (FR-015/FR-016).
func test_07_cascalho_limita_teto_e_expira() -> void:
	controller.fator_dificuldade = 1.0
	controller.speed = GameConfig.max_speed
	controller.aplicar_efeito_cascalho(0.5, 0.6, 1.0)
	Input.action_press("accelerate")
	controller._apply_vertical_physics(1.0 / 60.0)
	var teto: float = GameConfig.max_speed * 0.6
	assert_bool(controller.speed <= teto + 0.001).is_true().override_failure_message(
		"Cascalho não limitou o teto: speed %.2f > %.2f" % [controller.speed, teto]
	)

	var delta: float = 1.0 / 60.0
	var decorrido: float = 0.0
	while controller.efeito_velocidade_tempo > 0.0 and decorrido < 2.0:
		controller._process(delta)
		decorrido += delta
	assert_bool(absf(decorrido - 0.5) <= 0.05).is_true()

	controller.speed = teto
	for i in 30:
		controller._apply_vertical_physics(delta)
	assert_bool(controller.speed > teto + 0.001).is_true().override_failure_message(
		"Teto do cascalho não expirou: speed travada em %.2f" % controller.speed
	)
	Input.action_release("accelerate")


## CASCALHO — colisão repetida renova por sobrescrita: nunca soma duração
## nem empilha fator (FR-016).
func test_08_cascalho_renovacao_sem_empilhar() -> void:
	controller.aplicar_efeito_cascalho(1.2, 0.6, 0.8)
	controller.efeito_velocidade_tempo = 0.1
	controller.aplicar_efeito_cascalho(1.2, 0.6, 0.8)
	assert_float(controller.efeito_velocidade_tempo).is_equal_approx(1.2, 0.001)
	assert_float(controller.efeito_velocidade_fator).is_equal_approx(0.6, 0.001)


## `reset()` limpa o efeito de cascalho (corrida nova). A poça não tem
## mais estado no veículo — nada a limpar lá.
func test_09_reset_limpa_efeitos() -> void:
	controller.aplicar_efeito_cascalho(1.0, 0.5, 0.7)
	controller.reset()
	assert_float(controller.efeito_velocidade_tempo).is_equal(0.0)
	assert_float(controller.efeito_velocidade_fator).is_equal(1.0)
	assert_float(controller.efeito_aderencia_cascalho).is_equal(1.0)
	assert_float(controller._fator_aderencia_efetivo()).is_equal_approx(1.0, 0.001)


## CASCALHO — atingido ⇒ efeito no veículo E reciclagem imediata (o item
## não fica na pista, ao contrário da poça).
func test_10_cascalho_recicla_no_impacto() -> void:
	if not manager.obstacle_hit.is_connected(_contar_acerto):
		manager.obstacle_hit.connect(_contar_acerto)
	player.position = Vector2(320.0, 432.0)
	var item := _bater(Obstacle.TIPO_CASCALHO)
	assert_int(_acertos).is_equal(1)
	assert_bool(manager.ativos.has(item)).is_false()
	assert_bool(manager.pool.has(item)).is_true()
	assert_float(player.controller.efeito_velocidade_tempo).is_equal_approx(
		GameConfig.cascalho_duracao, 0.001
	)


## SC-009 — sonda de 100 encontros em Desafio (4,0× ⇒ 6,7 px/quadro) com
## 0 atravessamentos: toda aproximação vira desvio+inércia no mesmo quadro
## (poça) ou efeito+reciclagem (cascalho); combustível intocado (FR-020).
func test_11_sonda_cem_encontros_desafio() -> void:
	track.update(1.0, 5000.0)
	_acertos = 0
	if not manager.obstacle_hit.is_connected(_contar_acerto):
		manager.obstacle_hit.connect(_contar_acerto)

	var atravessamentos: int = 0
	for i in 100:
		player.position = Vector2(320.0, 432.0)
		var item := _bater(Obstacle.TIPO_POCA)
		# Atravessamento = poça AINDA ativa (ATIVO) após o quadro — o desvio
		# deveria ter sido registrado e marcado inerte.
		if item.estado == Obstacle.Estado.ATIVO:
			atravessamentos += 1
		assert_int(item.estado).is_equal(Obstacle.Estado.ATINGIDO)
		assert_float(player.position.x).is_equal_approx(309.0, 0.001)
		manager.reset()  # simula a poça saindo da tela para o próximo encontro

	assert_int(_acertos).is_equal(100).override_failure_message(
		"Sonda: %d contatos em 100 encontros" % _acertos
	)
	assert_int(atravessamentos).is_equal(0)
	assert_float(fuel.get_atual()).is_equal(100.0).override_failure_message(
		"Obstáculo mexeu no combustível (FR-015: intocado)"
	)
	assert_float(fuel.get_perda_colisao_corrida()).is_equal(0.0)


## SC-009 (cascalho) — 100 encontros: sempre efeito + reciclagem, efeito
## renovado (nunca empilhado) a cada encontro.
func test_12_sonda_cascalho_cem_encontros() -> void:
	track.update(1.0, 5000.0)
	_acertos = 0
	if not manager.obstacle_hit.is_connected(_contar_acerto):
		manager.obstacle_hit.connect(_contar_acerto)

	var atraves: int = 0
	for i in 100:
		player.position = Vector2(320.0, 432.0)
		var item := _bater(Obstacle.TIPO_CASCALHO)
		if manager.ativos.has(item):
			atraves += 1
		assert_float(player.controller.efeito_velocidade_tempo).is_equal_approx(
			GameConfig.cascalho_duracao, 0.001
		).override_failure_message("Efeito do cascalho empilhou ou não renovou")
		player.controller.reset()

	assert_int(_acertos).is_equal(100)
	assert_int(atraves).is_equal(0)


## SC-009 (T043) — aproximação REAL por rolagem em Desafio: o obstáculo
## nasce acima da tela e desce até o carro; em 100 aproximações, 0
## atravessamentos sem ativação (o encontro não nasce já sobreposto).
func test_13_sonda_cruzamento_por_rolagem_desafio() -> void:
	track.update(1.0, 5000.0)
	_acertos = 0
	if not manager.obstacle_hit.is_connected(_contar_acerto):
		manager.obstacle_hit.connect(_contar_acerto)
	manager.definir_disponivel(false)  # só os encontros do teste rolam

	var atravessamentos: int = 0
	for i in 100:
		player.position = Vector2(320.0, 432.0)
		var item: Obstacle = manager.pool.pop_back()
		manager.ativos.append(item)
		item.definir_tipo(Obstacle.TIPO_POCA)
		item.ativar(Vector2(320.0, -GameConfig.obstaculo_tamanho_poca.y))

		var quadros: int = 0
		while manager.ativos.has(item) \
				and item.estado == Obstacle.Estado.ATIVO and quadros < 150:
			manager.update(1.0 / 60.0, road, [], track, player)
			quadros += 1
		if item.estado == Obstacle.Estado.ATIVO:
			atravessamentos += 1  # saiu da tela sem nunca ser detectado
		manager.reset()

	assert_int(_acertos).is_equal(100).override_failure_message(
		"Sonda por rolagem: %d ativações em 100 aproximações" % _acertos
	)
	assert_int(atravessamentos).is_equal(0).override_failure_message(
		"%d atravessamentos sem ativação (SC-009)" % atravessamentos
	)
	assert_float(fuel.get_perda_colisao_corrida()).is_equal(0.0)
