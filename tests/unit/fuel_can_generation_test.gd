extends GdUnitTestSuite

## SPEC-008 / teste obrigatório F (dificuldade e geração) — US7.
## FuelCanManager: ordem de frequência por ambiente (SC-010: planície >
## deserto > floresta > gelo), teto simultâneo, piso/teto por corrida,
## offsets da largada/chegada, espaçamentos, ausência de NPCs no nascimento
## (FR-022/FR-030) e ausência de geração com estrada parada (SC-022 análogo).

var manager: FuelCanManager
var road: Road
var track: TrackManager
var player: PlayerVehicle

var _ambiente_original: String
var _intervalo_original: float
var _min_spacing_original: float
var _npc_spacing_original: float
var _start_original: float
var _finish_original: float
var _max_active_original: int
var _min_race_original: int
var _max_race_original: int
var _rate_original: Dictionary
var _unidades_original: float
var _total_original: float

## Contadores de sinal — vars de membro (lambdas capturam int por valor).
var _nascimentos: int = 0
var _violados: Array = []
var _npc_teste: TrafficVehicle = null


func before_test() -> void:
	_nascimentos = 0
	_violados = []
	_npc_teste = null
	_ambiente_original = GameConfig.current_environment_id
	_intervalo_original = GameConfig.fuel_can_spawn_interval_distance
	_min_spacing_original = GameConfig.fuel_can_min_spacing
	_npc_spacing_original = GameConfig.fuel_can_npc_spacing
	_start_original = GameConfig.fuel_can_start_offset
	_finish_original = GameConfig.fuel_can_finish_offset
	_max_active_original = GameConfig.fuel_can_max_active
	_min_race_original = GameConfig.fuel_can_min_per_race
	_max_race_original = GameConfig.fuel_can_max_per_race
	_rate_original = GameConfig.fuel_can_spawn_rate.duplicate()
	_unidades_original = GameConfig.track_units_to_km
	_total_original = GameConfig.track_total_distance
	GameConfig.track_units_to_km = 0.00034722
	GameConfig.track_total_distance = 5.0
	GameConfig.current_environment_id = "PLAINS"

	manager = FuelCanManager.new()
	add_child(manager)
	manager.setup()
	road = Road.new()
	road.scroll_speed = 100.0
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	player = PlayerVehicle.new()
	player.position = Vector2(320.0, 432.0)
	player.controller.speed = 100.0


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	GameConfig.fuel_can_spawn_interval_distance = _intervalo_original
	GameConfig.fuel_can_min_spacing = _min_spacing_original
	GameConfig.fuel_can_npc_spacing = _npc_spacing_original
	GameConfig.fuel_can_start_offset = _start_original
	GameConfig.fuel_can_finish_offset = _finish_original
	GameConfig.fuel_can_max_active = _max_active_original
	GameConfig.fuel_can_min_per_race = _min_race_original
	GameConfig.fuel_can_max_per_race = _max_race_original
	GameConfig.fuel_can_spawn_rate = _rate_original
	GameConfig.track_units_to_km = _unidades_original
	GameConfig.track_total_distance = _total_original
	manager.free()
	road.free()
	track.free()
	player.free()


## Percorre `km` quilômetros da corrida a 100 un/s, atualizando track e
## manager na ordem do quadro de PLAYING (R9, sem os passos de colisão).
func _dirigir(km: float) -> void:
	var delta: float = 1.0 / 60.0
	var passos: int = int(km / (100.0 * GameConfig.track_units_to_km * delta))
	for i in passos:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)


func _contar_nascimento(_can: FuelCan = null) -> void:
	_nascimentos += 1


func _checar_npc(c: FuelCan) -> void:
	if _npc_teste == null:
		return
	var meia: Vector2 = Vector2(32.0, 51.0) * 0.5
	var caixa := Rect2(c.position - meia, meia * 2.0).grow(GameConfig.fuel_can_npc_spacing)
	if caixa.intersects(_npc_teste.get_occupied_area()):
		_violados.append(c)


## F1 — ordem de frequência por ambiente: para a mesma distância dirigida,
## planície > deserto > floresta > gelo (SC-010, por construção das taxas).
func test_f1_ordem_por_ambiente() -> void:
	var contagens := {}
	for ambiente in ["PLAINS", "DESERT", "FOREST", "ICE"]:
		GameConfig.current_environment_id = ambiente
		manager.reset()
		track.setup(5.0)
		track.reset()
		# Avança para além do start_offset antes de medir a janela.
		track.update(1.0, 5000.0)
		track.update(0.1, 0.0)
		var nascimentos_antes: int = _nascimentos
		if not manager.fuel_can_spawned.is_connected(_contar_nascimento):
			manager.fuel_can_spawned.connect(_contar_nascimento)
		var percorrida_antes: float = track.get_percorrida()
		_dirigir(2.0)
		var nascimentos_janela: int = _nascimentos - nascimentos_antes
		contagens[ambiente] = nascimentos_janela
		# A janela dirigida não pode estourar o fim da corrida.
		assert_bool(track.get_percorrida() < 5.0).is_true()
		assert_bool(track.get_percorrida() > percorrida_antes).is_true()

	assert_int(contagens["PLAINS"]).is_greater(int(contagens["DESERT"]))
	assert_int(contagens["DESERT"]).is_greater(int(contagens["FOREST"]))
	assert_int(contagens["FOREST"]).is_greater(int(contagens["ICE"]))


## F2 — piso e teto por corrida: corrida completa gera dentro de
## [min_per_race, max_per_race] (Clarificação).
func test_f2_piso_e_teto_por_corrida() -> void:
	GameConfig.current_environment_id = "ICE"  # menor taxa: o piso deve aparecer
	manager.reset()
	track.setup(5.0)
	track.reset()
	track.update(1.0, 5000.0)  # além do start_offset
	_nascimentos = 0
	if not manager.fuel_can_spawned.is_connected(_contar_nascimento):
		manager.fuel_can_spawned.connect(_contar_nascimento)

	# Dirige até a janela de spawn se fechar (restante < finish_offset).
	while track.get_restante() >= GameConfig.fuel_can_finish_offset:
		_dirigir(0.2)

	assert_bool(_nascimentos >= GameConfig.fuel_can_min_per_race).is_true()
	assert_bool(_nascimentos <= GameConfig.fuel_can_max_per_race).is_true()


## F3 — offsets: nada nasce antes do start_offset nem depois do finish_offset
## da chegada (FR-029).
func test_f3_offsets_de_largada_e_chegada() -> void:
	GameConfig.current_environment_id = "PLAINS"
	manager.reset()
	track.setup(5.0)
	track.reset()
	_nascimentos = 0
	if not manager.fuel_can_spawned.is_connected(_contar_nascimento):
		manager.fuel_can_spawned.connect(_contar_nascimento)

	# Antes do start_offset: 0,10 km < 0,15 km.
	_dirigir(0.10)
	assert_int(_nascimentos).is_equal(0)

	# Perto da chegada: força percorrida quase no total.
	track.setup(5.0)
	track.reset()
	track.update(1.0, 999999.0)  # capado no total ⇒ restante 0 < finish_offset
	var antes_fim: int = _nascimentos
	_dirigir(0.5)
	assert_int(_nascimentos).is_equal(antes_fim)


## F4 — teto simultâneo: `ativos` nunca excede fuel_can_max_active (FR-031).
func test_f4_teto_simultaneo() -> void:
	GameConfig.current_environment_id = "PLAINS"
	manager.reset()
	track.setup(5.0)
	track.reset()
	track.update(1.0, 5000.0)

	var delta: float = 1.0 / 60.0
	for i in 6000:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)
		assert_bool(manager.ativos.size() <= GameConfig.fuel_can_max_active).is_true()


## F5 — espaçamento entre galões: nenhum par de galões ATIVOS tem ambos os
## eixos abaixo de fuel_can_min_spacing, em nenhum quadro (FR-030). O
## predicado vale por construção: galões reciclados saem do conjunto e os
## ativos transladam juntos na vertical (dy constante entre pares).
func test_f5_espacamento_entre_galoes() -> void:
	GameConfig.current_environment_id = "PLAINS"
	manager.reset()
	track.setup(5.0)
	track.reset()
	track.update(1.0, 5000.0)

	var delta: float = 1.0 / 60.0
	var passos: int = int(3.0 / (100.0 * GameConfig.track_units_to_km * delta))
	for i in passos:
		track.update(delta, 100.0)
		manager.update(delta, road, [], track, player)
		for a in manager.ativos.size():
			for b in range(a + 1, manager.ativos.size()):
				var dx: float = absf(manager.ativos[a].position.x - manager.ativos[b].position.x)
				var dy: float = absf(manager.ativos[a].position.y - manager.ativos[b].position.y)
				var colidiria: bool = (
					dx < GameConfig.fuel_can_min_spacing
					and dy < GameConfig.fuel_can_min_spacing
				)
				assert_bool(colidiria).is_false()

	assert_bool(manager.gerados_na_corrida >= 2).is_true()


## F6 — nunca nasce sobre NPC (FR-022): com um NPC na faixa de nascimento, o
## nascimento é adiado até uma posição livre — zero interseções observadas.
func test_f6_nunca_sobre_npc() -> void:
	GameConfig.current_environment_id = "PLAINS"
	manager.reset()
	track.setup(5.0)
	track.reset()
	track.update(1.0, 5000.0)

	var npc := TrafficVehicle.new()
	add_child(npc)
	var data := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["passeio"])
	data.garantir_size()
	npc.activate(data, 320.0, FuelCanManager.Y_SPAWN)
	_npc_teste = npc
	_violados = []
	if not manager.fuel_can_spawned.is_connected(_checar_npc):
		manager.fuel_can_spawned.connect(_checar_npc)

	var delta: float = 1.0 / 60.0
	for i in 3000:
		track.update(delta, 100.0)
		manager.update(delta, road, [npc], track, player)

	assert_int(_violados.size()).is_equal(0)
	npc.free()
	_npc_teste = null


## F7 — estrada parada: sem rolagem, nada nasce e a distância de geração não
## acumula (SC-022 análogo, Clarificação de velocidade).
func test_f7_parado_nao_gera() -> void:
	GameConfig.current_environment_id = "PLAINS"
	manager.reset()
	track.setup(5.0)
	track.reset()
	track.update(1.0, 5000.0)
	road.scroll_speed = 0.0
	_nascimentos = 0
	if not manager.fuel_can_spawned.is_connected(_contar_nascimento):
		manager.fuel_can_spawned.connect(_contar_nascimento)

	for i in 600:
		manager.update(1.0 / 60.0, road, [], track, player)

	assert_int(_nascimentos).is_equal(0)
	assert_float(manager.distancia_desde_ultima).is_equal(0.0)
