extends GdUnitTestSuite

## T049 / SC-010, SC-015 — estabilidade em 10 minutos contínuos de partida:
## nenhum crescimento indefinido de veículos ou elementos. O que se mede é o
## POOL (objetos criados) e a contagem ativa: ambos precisam estagnar, porque
## todo objeto que sai da tela volta ao pool em vez de virar lixo.

const QUADROS_10_MIN: int = 36000
## 100 s de aquecimento: a população de decoração continua preenchendo as
## profundidades por mais de um minuto, então medir o "estado estacionário"
## logo após 1000 quadros captava a rampa de criação e não o repouso.
const AQUECIMENTO: int = 6000
const TETO_DECORACAO: int = 60


class FakeRoad:
	extends Road

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func get_boundaries_for_player_y(_y: float) -> Dictionary:
		return {"left": 248.0, "right": 392.0}

	func get_left_boundary() -> float:
		return 248.0

	func get_right_boundary() -> float:
		return 392.0


var transito: TrafficManager
var decoracao: DecorationManager
var road: FakeRoad


func before_test() -> void:
	road = FakeRoad.new()
	road.scroll_speed = 80.0

	transito = TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	transito.setup(categorias)

	decoracao = DecorationManager.new()
	decoracao.setup(GameConfig.DECORATION_LIBRARIES)
	decoracao.set_environment("PLAINS")


func after_test() -> void:
	transito.free()
	decoracao.free()
	road.free()
	transito = null
	decoracao = null
	road = null


func test_pools_reach_steady_state_in_ten_minutes() -> void:
	for i in AQUECIMENTO:
		transito.update(1.0 / 60.0, road)
		decoracao.update(1.0 / 60.0, road)

	var pool_transito: int = transito.pool_size
	var pool_decoracao: int = decoracao.pool_size
	var ativos_transito: int = transito.active_count
	var ativos_decoracao: int = decoracao.active_count

	# 10 minutos contínuos, amostrando a cada 1000 quadros (~16,7 s).
	var restantes: int = QUADROS_10_MIN
	# Últimas duas amostras de pool: o critério de repouso é a ESTAGNAÇÃO delas,
	# não a igualdade com o valor medido no aquecimento.
	var penultimo_transito: int = -1
	var penultimo_decoracao: int = -1
	var ultimo_transito: int = -1
	var ultimo_decoracao: int = -1
	while restantes > 0:
		var lote: int = mini(1000, restantes)
		for i in lote:
			transito.update(1.0 / 60.0, road)
			decoracao.update(1.0 / 60.0, road)
		restantes -= lote

		assert_int(transito.active_count).is_less_equal(
			GameConfig.traffic_max_vehicles
		).override_failure_message("SC-015: veículos ativos acima do limite")
		assert_int(decoracao.active_count).is_less_equal(
			TETO_DECORACAO
		).override_failure_message("SC-010: elementos ativos acima do teto")
		assert_int(transito.pool_size).is_less_equal(
			GameConfig.traffic_max_vehicles + 4
		).override_failure_message("SC-015: pool de trânsito cresceu sem limite")
		assert_int(decoracao.pool_size).is_less_equal(
			TETO_DECORACAO
		).override_failure_message("SC-010: pool de decoração cresceu sem limite")

		penultimo_transito = ultimo_transito
		penultimo_decoracao = ultimo_decoracao
		ultimo_transito = transito.pool_size
		ultimo_decoracao = decoracao.pool_size

	# Depois de 10 min as duas últimas amostras precisam ser idênticas: reciclar
	# não cria objeto novo (FR-015, FR-043). Os teto por amostra acima já pegam
	# crescimento indefinido; aqui se pega o pool ainda subindo no fim da corrida
	# (12 -> 14 durante a rampa de população, por exemplo).
	assert_int(ultimo_transito).is_equal(penultimo_transito).override_failure_message(
		"SC-015: pool de trânsito ainda crescia no fim da corrida (%d -> %d, aquecimento: %d)"
		% [penultimo_transito, ultimo_transito, pool_transito]
	)
	assert_int(ultimo_decoracao).is_equal(penultimo_decoracao).override_failure_message(
		"SC-010: pool de decoração ainda crescia no fim da corrida (%d -> %d, aquecimento: %d)"
		% [penultimo_decoracao, ultimo_decoracao, pool_decoracao]
	)

	# Os dois sistemas continuam vivos ao fim da partida (não congelaram).
	assert_int(transito.active_count).is_greater(
		0
	).override_failure_message("SC-015: trânsito parou de existir ao fim da partida")
	assert_int(decoracao.active_count).is_greater(
		0
	).override_failure_message("SC-010: decoração parou de existir ao fim da partida")
	assert_int(ativos_transito).is_greater(0).override_failure_message(
		"SC-015: sem veículos no steady state"
	)
	assert_int(ativos_decoracao).is_greater(0).override_failure_message(
		"SC-010: sem elementos no steady state"
	)


## T059 / SC-006, FR-019 — em 100% dos quadros de uma partida contínua de
## 10 minutos, no máximo 2 veículos ativos estão a menos de
## `traffic_min_spacing` um do outro.
##
## Usa a velocidade máxima da estrada: com `scroll_speed` igual a de uma
## categoria, o veículo daquela categoria fica parado na linha de criação e
## trava os nascimentos (mesma degeneração já registrada em
## `test_no_immediate_overlap_after_spawn`).

## T059 / SC-006, FR-019 — em 100% dos quadros de uma partida contínua de
## 10 minutos, no máximo 2 veículos ativos estão a menos de
## `traffic_min_spacing` um do outro.
##
## Usa a velocidade máxima da estrada: com `scroll_speed` igual à de uma
## categoria, o veículo daquela categoria fica parado na linha de criação e
## trava os nascimentos (mesma degeneração registrada em
## `test_no_immediate_overlap_after_spawn`). Com todos os veículos mais lentos
## que a estrada, todos descem — é o cenário de ultrapassagem contínua.
func test_sc006_traffic_spacing_in_ten_minutes() -> void:
	road.scroll_speed = GameConfig.max_speed

	var piores_veiculos: int = 0
	var piores_pares: int = 0
	var quadros_com_veiculos: int = 0

	for i in QUADROS_10_MIN:
		transito.update(1.0 / 60.0, road)

		var veiculos_ruins: Dictionary = {}
		var pares_ruins: int = 0
		var ativos: Array[TrafficVehicle] = transito.active_vehicles
		if not ativos.is_empty():
			quadros_com_veiculos += 1

		for a in ativos.size():
			for b in range(a + 1, ativos.size()):
				if (
					absf(ativos[a].position.y - ativos[b].position.y)
					< GameConfig.traffic_min_spacing
				):
					pares_ruins += 1
					veiculos_ruins[ativos[a].get_instance_id()] = true
					veiculos_ruins[ativos[b].get_instance_id()] = true

		piores_pares = maxi(piores_pares, pares_ruins)
		piores_veiculos = maxi(piores_veiculos, veiculos_ruins.size())

	assert_int(quadros_com_veiculos).is_greater(
		QUADROS_10_MIN / 2
	).override_failure_message("SC-006: corrida longa sem trânsito o bastante para verificar")
	assert_int(transito.active_count).is_greater(0).override_failure_message(
		"SC-006: trânsito parou de existir ao fim da partida"
	)
	assert_int(piores_veiculos).is_less_equal(2).override_failure_message(
		"SC-006: %d veículos a menos de %.0f px um do outro no mesmo quadro (pares: %d)"
		% [piores_veiculos, GameConfig.traffic_min_spacing, piores_pares]
	)
