extends GdUnitTestSuite

## SPEC-008 / teste obrigatório E (coleta) — US6.
## FuelCanManager: coleta exatamente 1× por sobreposição própria (sem
## CollisionSystem — SC-009), restauração via FuelSystem (autoridade única,
## R4/FR-033), reciclagem obrigatória na base e reutilização limpa do pool
## (FR-030, SC-011), movimento apenas pela rolagem (Clarificação) e
## preservação sob pausa (SC-012).

var manager: FuelCanManager
var sistema: FuelSystem
var road: Road
var track: TrackManager
var player: PlayerVehicle

var _restore_original: float
var _cap_original: float
var _inicial_original: float
var _max_active_original: int

## Contadores de sinal — vars de membro (lambdas capturam int por valor).
var _coletas: int = 0
var _emissoes: int = 0


func before_test() -> void:
	_restore_original = GameConfig.fuel_can_restore_amount
	_cap_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_max_active_original = GameConfig.fuel_can_max_active
	GameConfig.fuel_can_restore_amount = 25.0
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0

	_coletas = 0
	_emissoes = 0
	manager = FuelCanManager.new()
	add_child(manager)
	manager.setup()
	sistema = FuelSystem.new()
	sistema.reset()
	road = Road.new()
	road.scroll_speed = 0.0
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	player = PlayerVehicle.new()
	player.position = Vector2(320.0, 432.0)
	player.controller.speed = 50.0
	manager.fuel_can_collected.connect(sistema.restaurar)


func _contar_coleta(_v: float = 0.0) -> void:
	_coletas += 1


func _contar_fuel(_a: float = 0.0, _c: float = 0.0) -> void:
	_emissoes += 1


func after_test() -> void:
	GameConfig.fuel_can_restore_amount = _restore_original
	GameConfig.fuel_capacity = _cap_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_can_max_active = _max_active_original
	manager.free()
	sistema.free()
	road.free()
	track.free()
	player.free()


func _injetar(pos: Vector2) -> FuelCan:
	var can := FuelCan.new()
	manager.add_child(can)
	can.preparar()
	can.ativar(pos)
	manager.ativos.append(can)
	return can


## E1 — coleta exatamente 1× mesmo com sobreposição por vários quadros; o
## galão volta ao pool no mesmo quadro (FR-030/FR-032, R8).
func test_e1_coleta_uma_vez() -> void:
	_injetar(Vector2(320.0, 432.0))
	manager.fuel_can_collected.connect(_contar_coleta)

	for i in 5:
		manager.update(1.0 / 60.0, road, [], track, player)

	assert_int(_coletas).is_equal(1)
	assert_int(manager.ativos.size()).is_equal(0)
	assert_int(manager.pool.size()).is_greater(0)


## E2 — restauração entra no FuelSystem e é limitada pela capacidade (R4).
func test_e2_restauracao_com_cap() -> void:
	# Drena parte do tanque para abrir espaço.
	sistema.update(30.0, 100.0)
	var antes: float = sistema.get_atual()
	_injetar(Vector2(320.0, 432.0))
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_float(sistema.get_atual()).is_equal_approx(minf(antes + 25.0, 100.0), 0.0001)

	# Perto do topo: o clamp limita no máximo.
	var quase_cheio := FuelSystem.new()
	quase_cheio.reset()
	quase_cheio.update(1.0, 100.0)
	quase_cheio._escrever(95.0)
	manager.fuel_can_collected.connect(quase_cheio.restaurar)
	_injetar(Vector2(320.0, 432.0))
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_float(quase_cheio.get_atual()).is_equal(100.0)
	quase_cheio.free()


## E3 — coleta NÃO é colisão (SC-009): a velocidade do jogador fica intacta,
## sem perda, deriva ou penalidade.
func test_e3_coleta_sem_efeitos_de_colisao() -> void:
	_injetar(Vector2(320.0, 432.0))
	player.controller.speed = 50.0
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_float(player.get_speed()).is_equal(50.0)
	assert_float(player.controller.aceleracao_bloqueada).is_equal(0.0)
	assert_float(player.controller.control_factor).is_equal(1.0)


## E4 — reciclagem na base: quem passa da borda volta ao pool (FR-030).
func test_e4_reciclagem_na_base() -> void:
	var can := _injetar(Vector2(320.0, 510.0))
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_bool(manager.ativos.has(can)).is_false()
	assert_bool(manager.pool.has(can)).is_true()
	assert_bool(can.visible).is_false()


## E5 — reutilização redefine posição, estado e visibilidade (FR-031, SC-011).
func test_e5_reutilizacao_limpa() -> void:
	var can := _injetar(Vector2(320.0, 432.0))
	manager.fuel_can_collected.connect(_contar_coleta)
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_bool(can.visible).is_false()
	assert_int(can.estado).is_equal(FuelCan.Estado.ATIVO)
	# Reapresentação: nova posição, visível e coletável de novo.
	can.ativar(Vector2(300.0, 100.0))
	assert_bool(can.visible).is_true()
	assert_int(can.estado).is_equal(FuelCan.Estado.ATIVO)


## E6 — sem velocidade própria (Clarificação): com a estrada parada o galão
## não se move.
func test_e6_sem_velocidade_propria() -> void:
	road.scroll_speed = 0.0
	var can := _injetar(Vector2(320.0, 100.0))
	manager.update(0.5, road, [], track, player)
	assert_float(can.position.y).is_equal(100.0)


## E7 — pausa: update com rolagem zero mantém as posições idênticas
## (SC-012 — o delta da pausa não desloca nada).
func test_e7_pausa_preserva_posicoes() -> void:
	road.scroll_speed = 0.0
	var can := _injetar(Vector2(320.0, 100.0))
	manager.update(0.1, road, [], track, player)
	manager.update(1.0, road, [], track, player)
	assert_float(can.position.y).is_equal(100.0)


## E8 — tanque cheio: coleta emite o evento mas não varia o combustível
## (no-op silencioso de restauração — R4).
func test_e8_tanque_cheio_noop() -> void:
	sistema.fuel_changed.connect(_contar_fuel)
	_injetar(Vector2(320.0, 432.0))
	manager.update(1.0 / 60.0, road, [], track, player)
	assert_int(_emissoes).is_equal(0)
	assert_float(sistema.get_atual()).is_equal(sistema.get_capacidade())
