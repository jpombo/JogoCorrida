extends GdUnitTestSuite

## SPEC-008 / teste obrigatório H (ciclo de vida — reset) + I (regressão).
## Reset completo e idempotente na largada (FR-003/FR-035, R10): tanque
## derivado cheio, progressão zerada, galões/marcadores sem resíduo, sistemas
## de trânsito/colisão/decoração/estrada zerados, 0 conexões repetidas
## (SC-012) e regressão zero das SPECs 001–007 (SC-013/SC-014).

var gm: GameplayManager

var _total_original: float
var _por_km_original: float
var _margem_original: float
var _cap_original: float
var _inicial_original: float


func before_test() -> void:
	_total_original = GameConfig.track_total_distance
	_por_km_original = GameConfig.fuel_consumption_per_distance
	_margem_original = GameConfig.fuel_safety_margin
	_cap_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	GameConfig.track_total_distance = 5.0
	GameConfig.fuel_consumption_per_distance = 60.0
	GameConfig.fuel_safety_margin = 60.0
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0

	gm = _montar_gm()
	GameState.reset()


func after_test() -> void:
	GameConfig.track_total_distance = _total_original
	GameConfig.fuel_consumption_per_distance = _por_km_original
	GameConfig.fuel_safety_margin = _margem_original
	GameConfig.fuel_capacity = _cap_original
	GameConfig.fuel_initial_amount = _inicial_original
	_desmontar_gm(gm)
	GameState.reset()


## H-reset 1 — `_reset_corrida` deixa cada sistema no estado de largada:
## tanque derivado cheio, progressão zero, estrada/trânsito/colisões/decoração
## zerados e posição inicial do jogador (FR-003, R10).
func test_hreset_1_estado_de_largada() -> void:
	# Sujou a corrida de propósito.
	gm.track_manager.update(10.0, 100.0)
	gm.fuel_system.update(10.0, 100.0)
	gm.player_vehicle.controller.speed = 80.0
	gm.player_vehicle.position.y = 300.0
	gm.collision_system._cooldowns["1:2"] = 0.5
	gm.collision_system.ultima_intensidade = 0.9

	gm._reset_corrida()

	# Tanque derivado da fórmula e cheio.
	assert_float(gm.fuel_system.get_capacidade()).is_equal(5.0 * 60.0 + 60.0)
	assert_float(gm.fuel_system.get_atual()).is_equal(gm.fuel_system.get_capacidade())

	# Progressão zerada, total da config.
	assert_float(gm.track_manager.get_percorrida()).is_equal(0.0)
	assert_float(gm.track_manager.get_total()).is_equal(5.0)
	assert_bool(gm.track_manager.esta_concluido()).is_false()

	# Veículo e flag.
	assert_float(gm.player_vehicle.get_speed()).is_equal(0.0)
	assert_bool(gm.player_vehicle.controller.aceleracao_bloqueada_por_combustivel).is_false()
	assert_float(gm.player_vehicle.position.y).is_equal_approx(
		GameConfig.initial_vertical_position * 480.0 - 24.0, 0.0001
	)

	# Colisões.
	assert_int(gm.collision_system._cooldowns.size()).is_equal(0)
	assert_float(gm.collision_system.ultima_intensidade).is_equal(0.0)


## H-reset 2 — idempotência: duas largadas seguidas produzem o mesmo estado,
## sem erro e sem efeitos acumulados (SC-012).
func test_hreset_2_idempotente() -> void:
	gm._reset_corrida()
	var cap1: float = gm.fuel_system.get_capacidade()
	var perc1: float = gm.track_manager.get_percorrida()

	gm._reset_corrida()
	assert_float(gm.fuel_system.get_capacidade()).is_equal(cap1)
	assert_float(gm.track_manager.get_percorrida()).is_equal(perc1)
	assert_float(gm.fuel_system.get_atual()).is_equal(cap1)


## H-reset 3 — conexões de sinais nunca duplicam com resets repetidos
## (SC-012: 0 conexões repetidas). O reset não reconecta — só `_ready`/`setup`.
func test_hreset_3_sem_conexoes_repetidas() -> void:
	var antes: int = GameState.state_changed.get_connections().size()
	gm._reset_corrida()
	gm._reset_corrida()
	var depois: int = GameState.state_changed.get_connections().size()
	assert_int(depois).is_equal(antes)


## H-reset 4 — transição READY → PLAYING dispara o reset exatamente uma vez
## por largada; PAUSED → PLAYING NÃO reseta (preserva o saldo — R4).
func test_hreset_4_gating_de_transicao() -> void:
	# Primeira largada (o reset instala o total da corrida no track).
	gm._reset_corrida()
	GameState.change_state(GameState.State.READY)

	# READY → PLAYING ⇒ reset.
	gm.track_manager.update(10.0, 100.0)
	var percorrida_suja: float = gm.track_manager.get_percorrida()
	assert_bool(percorrida_suja > 0.0).is_true()
	GameState.change_state(GameState.State.PLAYING)
	assert_float(gm.track_manager.get_percorrida()).is_equal(0.0)

	# PLAYING → PAUSED → PLAYING ⇒ sem reset (saldo preservado).
	gm.track_manager.update(10.0, 100.0)
	var percorrida_antes: float = gm.track_manager.get_percorrida()
	GameState.change_state(GameState.State.PAUSED)
	GameState.change_state(GameState.State.PLAYING)
	assert_float(gm.track_manager.get_percorrida()).is_equal(percorrida_antes)


## H-reset 5 — encerramento por VICTORY ou GAME_OVER devolve os galões ao
## pool no próprio instante da transição (FR-031, SC-011): 0 galões ativos
## permanecem após qualquer encerramento, sem depender do próximo reset de
## largada. Cobre o gap da Phase 12 (Convergence).
func test_hreset_5_encerramento_limpa_galoes() -> void:
	# largada (READY → PLAYING dispara o reset completo).
	GameState.change_state(GameState.State.READY)
	GameState.change_state(GameState.State.PLAYING)

	# Injeta dois galões ativos e força o cruzamento COMPLETO da chegada
	# (topo da banda ≥ base do carro, geometria real pós-reset).
	var pool_antes: int = gm.items_layer.pool.size()
	_injetar_galoes(2)
	assert_int(gm.items_layer.ativos.size()).is_equal(2)
	gm.track_layer.banda_chegada.position.y = (
		gm.player_vehicle.position.y + GameConfig.player_hitbox_size.y
	)
	gm._avaliar_transicoes()
	assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)
	assert_int(gm.items_layer.ativos.size()).is_equal(0)
	# Os dois galões injetados voltaram ao pool (reciclagem obrigatória).
	assert_int(gm.items_layer.pool.size()).is_equal(pool_antes + 2)

	# Reinício e novo encerramento por GAME_OVER: mesma limpeza.
	GameState.change_state(GameState.State.READY)
	GameState.change_state(GameState.State.PLAYING)
	_injetar_galoes(3)
	assert_int(gm.items_layer.ativos.size()).is_equal(3)
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 0.0
	gm._avaliar_transicoes()
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)
	assert_int(gm.items_layer.ativos.size()).is_equal(0)


## Injeta `quantidade` galões ativados direto no pool/ativos (posição acima
## da tela, fora de qualquer hitbox — sem efeitos colaterais de gameplay).
func _injetar_galoes(quantidade: int) -> void:
	for i in quantidade:
		var can: FuelCan = FuelCan.new()
		gm.items_layer.add_child(can)
		can.preparar()
		can.ativar(Vector2(200.0 + i * 64.0, FuelCanManager.Y_SPAWN))
		gm.items_layer.ativos.append(can)


## I1 — capacidade derivada respeita a configuração vigente (SC-016): trocar
## os parâmetros antes da largada muda o tanque sem tocar no código.
func test_i1_capacidadeSegue_config() -> void:
	GameConfig.track_total_distance = 2.0
	GameConfig.fuel_safety_margin = 10.0
	gm._reset_corrida()
	assert_float(gm.fuel_system.get_capacidade()).is_equal(2.0 * 60.0 + 10.0)


## Monta o gerenciador sintético com todos os sistemas consultados pelo reset
## — fora da árvore de cena, no padrão das suítes anteriores.
func _montar_gm() -> GameplayManager:
	var gerente := GameplayManager.new()
	gerente.game_state = GameState
	gerente.fuel_system = FuelSystem.new()
	gerente.track_manager = TrackManager.new()
	gerente.track_layer = TrackMarkers.new()
	gerente.items_layer = FuelCanManager.new()
	gerente.road = Road.new()
	gerente.player_vehicle = PlayerVehicle.new()
	gerente.traffic_layer = TrafficManager.new()
	gerente.decoration_layer = DecorationManager.new()
	gerente.items_layer.setup()
	# Espelho do `_ready` (sem árvore de cena): a transição READY → PLAYING
	# precisa do handler ligado para exercitar o gating de reset.
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	return gerente


func _desmontar_gm(gerente: GameplayManager) -> void:
	gerente.fuel_system.free()
	gerente.track_manager.free()
	gerente.track_layer.free()
	gerente.items_layer.free()
	gerente.road.free()
	gerente.player_vehicle.free()
	gerente.traffic_layer.free()
	gerente.decoration_layer.free()
	gerente.free()
