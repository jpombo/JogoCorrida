extends GdUnitTestSuite

## SPEC-011 / T019+T026 (US3/US4) — ObstacleManager: spawn por distância no
## intervalo, rejeição/reagendamento (limites, espaçamento, NPC, jogador),
## gate `disponivel` (SC-007), reciclagem na base, `reset()` devolvendo à
## pool e detecção AABB aplicando o efeito no controlador (FR-014/FR-017,
## contract obstacle_integration §1).

var manager: ObstacleManager
var road: Road
var track: TrackManager
var player: PlayerVehicle

var _intervalo_original: float
var _max_original: int
var _spacing_original: float
var _npc_spacing_original: float
var _start_original: float
var _finish_original: float
var _unidades_original: float
var _total_original: float
var _tamanho_poca_original: Vector2
var _tamanho_cascalho_original: Vector2
var _peso_poca_original: int
var _peso_cascalho_original: int

var _nascimentos: int = 0
var _violados: Array = []
var _npc_teste: TrafficVehicle = null
var _acertos: int = 0


func before_test() -> void:
	_nascimentos = 0
	_violados = []
	_acertos = 0
	_npc_teste = null
	_intervalo_original = GameConfig.obstaculo_intervalo_km
	_max_original = GameConfig.obstaculo_max_ativos
	_spacing_original = GameConfig.obstaculo_min_spacing
	_npc_spacing_original = GameConfig.obstaculo_npc_spacing
	_start_original = GameConfig.obstaculo_start_offset_km
	_finish_original = GameConfig.obstaculo_finish_offset_km
	_unidades_original = GameConfig.track_units_to_km
	_total_original = GameConfig.track_total_distance
	_tamanho_poca_original = GameConfig.obstaculo_tamanho_poca
	_tamanho_cascalho_original = GameConfig.obstaculo_tamanho_cascalho
	_peso_poca_original = GameConfig.obstaculo_peso_poca
	_peso_cascalho_original = GameConfig.obstaculo_peso_cascalho
	GameConfig.track_units_to_km = 0.00034722
	GameConfig.track_total_distance = 5.0
	GameConfig.obstaculo_intervalo_km = 0.25
	GameConfig.obstaculo_start_offset_km = 0.05
	GameConfig.obstaculo_finish_offset_km = 0.25
	GameConfig.obstaculo_max_ativos = 3
	GameConfig.obstaculo_min_spacing = 120.0
	GameConfig.obstaculo_npc_spacing = 24.0

	manager = ObstacleManager.new()
	add_child(manager)
	manager.configurar()
	road = Road.new()
	road.scroll_speed = 100.0
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	player = PlayerVehicle.new()
	player.position = Vector2(320.0, 432.0)
	player.controller.speed = 100.0


func after_test() -> void:
	GameConfig.obstaculo_intervalo_km = _intervalo_original
	GameConfig.obstaculo_max_ativos = _max_original
	GameConfig.obstaculo_min_spacing = _spacing_original
	GameConfig.obstaculo_npc_spacing = _npc_spacing_original
	GameConfig.obstaculo_start_offset_km = _start_original
	GameConfig.obstaculo_finish_offset_km = _finish_original
	GameConfig.track_units_to_km = _unidades_original
	GameConfig.track_total_distance = _total_original
	GameConfig.obstaculo_tamanho_poca = _tamanho_poca_original
	GameConfig.obstaculo_tamanho_cascalho = _tamanho_cascalho_original
	GameConfig.obstaculo_peso_poca = _peso_poca_original
	GameConfig.obstaculo_peso_cascalho = _peso_cascalho_original
	manager.free()
	road.free()
	track.free()
	player.free()


func _dirigir(km: float) -> void:
	var delta: float = 1.0 / 60.0
	var passos: int = int(km / (100.0 * GameConfig.track_units_to_km * delta))
	for i in passos:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)


func _contar_nascimento(_o: Obstacle = null) -> void:
	_nascimentos += 1


func _checar_npc(o: Obstacle) -> void:
	if _npc_teste == null:
		return
	var caixa := Rect2(o.position - o.tamanho * 0.5, o.tamanho).grow(
		GameConfig.obstaculo_npc_spacing
	)
	if caixa.intersects(_npc_teste.get_occupied_area()):
		_violados.append(o)


func _checar_acerto(_tipo: String = "") -> void:
	_acertos += 1


## FR-017 — spawn por distância: dirigindo ~1,0 km com intervalo 0,25 km
## nascem ≥2 obstáculos e a distância zera a cada nascimento.
func test_01_spawn_por_distancia() -> void:
	track.update(1.0, 5000.0)  # além do start_offset
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)
	_dirigir(1.0)
	assert_bool(_nascimentos >= 2).is_true().override_failure_message(
		"1,0 km com intervalo 0,25 km gerou só %d obstáculos" % _nascimentos
	)
	# Após o último nascimento só resta o trecho seguinte — ou um candidato
	# pendente segurando a integra (limite de expiração = 2 intervalos).
	assert_bool(manager.distancia_desde_ultima < GameConfig.obstaculo_intervalo_km * 2.0).is_true()


## FR-017 — pista estreita demais: o candidato fica pendente e nada nasce
## (reagendamento, nunca geração inválida).
func test_02_rejeicao_fora_dos_limites() -> void:
	road.left_boundary = 0.0
	road.right_boundary = 10.0
	track.update(1.0, 5000.0)
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)
	_dirigir(1.0)
	assert_int(_nascimentos).is_equal(0)
	assert_bool(manager.spawn_pendente.is_empty()).is_false().override_failure_message(
		"Candidato inválido foi descartado em vez de reagendado"
	)


## FR-017 — espaçamento entre obstáculos ATIVOS mantido em todo quadro.
func test_03_espacamento_entre_ativos() -> void:
	track.update(1.0, 5000.0)
	var delta: float = 1.0 / 60.0
	var passos: int = int(2.0 / (100.0 * GameConfig.track_units_to_km * delta))
	for i in passos:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)
		for a in manager.ativos.size():
			for b in range(a + 1, manager.ativos.size()):
				var dx: float = absf(manager.ativos[a].position.x - manager.ativos[b].position.x)
				var dy: float = absf(manager.ativos[a].position.y - manager.ativos[b].position.y)
				assert_bool(dx < GameConfig.obstaculo_min_spacing and dy < GameConfig.obstaculo_min_spacing).is_false()


## FR-017 — nunca nasce sobre NPC: zero interseções observadas no spawn.
func test_04_nunca_sobre_npc() -> void:
	track.update(1.0, 5000.0)
	var npc := TrafficVehicle.new()
	add_child(npc)
	var data := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["passeio"])
	data.garantir_size()
	npc.activate(data, 320.0, ObstacleManager.Y_SPAWN)
	_npc_teste = npc
	_violados = []
	if not manager.obstacle_spawned.is_connected(_checar_npc):
		manager.obstacle_spawned.connect(_checar_npc)

	var delta: float = 1.0 / 60.0
	for i in 3000:
		track.update(delta, 100.0)
		manager.update(delta, road, [npc], track, player)

	assert_int(_violados.size()).is_equal(0)
	npc.free()
	_npc_teste = null


## FR-017 — nunca nasce sobre o jogador (reagendado enquanto o jogador
## estiver na faixa de nascimento).
func test_05_rejeicao_por_proximidade_do_jogador() -> void:
	player.position = Vector2(320.0, ObstacleManager.Y_SPAWN)
	track.update(1.0, 5000.0)
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)
	_dirigir(0.8)
	assert_int(_nascimentos).is_equal(0).override_failure_message(
		"Nasceu obstáculo com o jogador na faixa de spawn"
	)


## SC-007/FR-018 — gate fechado ⇒ zero nascimentos; gate aberto ⇒ nascem.
func test_06_gate_de_disponibilidade() -> void:
	track.update(1.0, 5000.0)
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)

	manager.definir_disponivel(false)
	_dirigir(0.8)
	assert_int(_nascimentos).is_equal(0)

	manager.definir_disponivel(true)
	_dirigir(0.8)
	assert_bool(_nascimentos >= 1).is_true()


## SC-007 — o gate é preservado pelo `reset()` (redefinido pelo
## orquestrador, não pelo reset).
func test_07_gate_preservado_apos_reset() -> void:
	manager.definir_disponivel(false)
	manager.reset()
	track.update(1.0, 5000.0)
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)
	_dirigir(0.8)
	assert_int(_nascimentos).is_equal(0)


## FR-016/FR-017 — reset devolve tudo à pool, zera a distância e a contagem.
func test_08_reset_devolve_a_pool() -> void:
	track.update(1.0, 5000.0)
	manager.definir_disponivel(true)
	_dirigir(0.6)
	assert_bool(manager.ativos.size() >= 1).is_true()

	manager.reset()

	assert_int(manager.ativos.size()).is_equal(0)
	assert_float(manager.distancia_desde_ultima).is_equal(0.0)
	assert_bool(manager.pool.size() >= GameConfig.obstaculo_max_ativos).is_true()
	for item in manager.pool:
		assert_bool(item.visible).is_false()


## Contrato §1.4 (ajustado no aceite T032) — detecção AABB por quadro:
## POÇA desvia o jogador de meio carro e fica INERTE na pista (continua
## visível/ativa até sair da tela — não recicla no impacto).
func test_09_deteccao_poca_desvia_e_permanece() -> void:
	if not manager.obstacle_hit.is_connected(_checar_acerto):
		manager.obstacle_hit.connect(_checar_acerto)
	var x_antes: float = player.position.x
	var item: Obstacle = manager.pool.pop_back()
	manager.ativos.append(item)
	item.definir_tipo(Obstacle.TIPO_POCA)
	item.ativar(player.position)

	manager.update(1.0 / 60.0, road, [], track, player)

	assert_int(_acertos).is_equal(1)
	# Desvio de meio carro (centro igual ⇒ empurrado para a esquerda).
	assert_float(player.position.x).is_equal_approx(
		x_antes - GameConfig.poca_desvio_lateral, 0.001
	)
	assert_int(item.estado).is_equal(Obstacle.Estado.ATINGIDO)
	assert_bool(manager.ativos.has(item)).is_true().override_failure_message(
		"Poça foi reciclada no impacto — deve permanecer até sair da tela"
	)
	assert_bool(item.visible).is_true()
	# Sem efeito residual no veículo (a poça não mexe em aderência).
	assert_float(player.controller._fator_aderencia_efetivo()).is_equal_approx(1.0, 0.001)
	# Só sai da pista rolando até a base.
	player.position.x = 1000.0
	var quadros: int = 0
	while manager.ativos.has(item) and quadros < 600:
		manager.update(1.0 / 60.0, road, [], track, player)
		quadros += 1
	assert_bool(manager.pool.has(item)).is_true()


## CASCALHO — atingido ⇒ efeito no controlador + reciclagem imediata
## (comportamento original preservado).
func test_09b_deteccao_cascalho_aplica_efeito_e_recicla() -> void:
	if not manager.obstacle_hit.is_connected(_checar_acerto):
		manager.obstacle_hit.connect(_checar_acerto)
	_acertos = 0
	var item: Obstacle = manager.pool.pop_back()
	manager.ativos.append(item)
	item.definir_tipo(Obstacle.TIPO_CASCALHO)
	item.ativar(player.position)

	manager.update(1.0 / 60.0, road, [], track, player)

	assert_int(_acertos).is_equal(1)
	assert_bool(manager.ativos.has(item)).is_false()
	assert_bool(manager.pool.has(item)).is_true()
	assert_float(player.controller.efeito_velocidade_tempo).is_equal_approx(
		GameConfig.cascalho_duracao, 0.001
	)


## FR-023/FR-024 — estrada parada não gera nem acumula distância.
func test_10_parado_nao_gera() -> void:
	track.update(1.0, 5000.0)
	road.scroll_speed = 0.0
	_nascimentos = 0
	if not manager.obstacle_spawned.is_connected(_contar_nascimento):
		manager.obstacle_spawned.connect(_contar_nascimento)
	for i in 600:
		manager.update(1.0 / 60.0, road, [], track, player)
	assert_int(_nascimentos).is_equal(0)
	assert_float(manager.distancia_desde_ultima).is_equal(0.0)


## Teto simultâneo: `ativos` nunca excede obstaculo_max_ativos.
func test_11_teto_simultaneo() -> void:
	GameConfig.obstaculo_intervalo_km = 0.05
	track.update(1.0, 5000.0)
	var delta: float = 1.0 / 60.0
	for i in 6000:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)
		assert_bool(manager.ativos.size() <= GameConfig.obstaculo_max_ativos).is_true()


## T038 / Constitution §VIII — sorteio ponderado de tipo (FR-026): peso 100
## de um tipo nunca devolve o outro; ambos zerados caem no fallback poça.
func test_12_sortear_tipo_pesos_extremos() -> void:
	GameConfig.obstaculo_peso_poca = 100
	GameConfig.obstaculo_peso_cascalho = 0
	for i in 50:
		assert_str(manager._sortear_tipo()).is_equal(Obstacle.TIPO_POCA)

	GameConfig.obstaculo_peso_poca = 0
	GameConfig.obstaculo_peso_cascalho = 100
	for i in 50:
		assert_str(manager._sortear_tipo()).is_equal(Obstacle.TIPO_CASCALHO)

	GameConfig.obstaculo_peso_poca = 0
	GameConfig.obstaculo_peso_cascalho = 0
	for i in 10:
		assert_str(manager._sortear_tipo()).is_equal(Obstacle.TIPO_POCA)


## T038 / Constitution §VIII — 50/50 produz os dois tipos em 200 sorteios
## (semântica estatística com folga: qualquer um dos dois com pelo menos 1).
func test_13_sortear_tipo_50_50_produz_os_dois() -> void:
	GameConfig.obstaculo_peso_poca = 50
	GameConfig.obstaculo_peso_cascalho = 50
	var pocas: int = 0
	var casc: int = 0
	for i in 200:
		if manager._sortear_tipo() == Obstacle.TIPO_POCA:
			pocas += 1
		else:
			casc += 1
	assert_int(pocas).is_greater(0)
	assert_int(casc).is_greater(0)
