extends GdUnitTestSuite

## T048 / SC-024, FR-060 — desempenho dos dois sistemas em operação nos 4
## ambientes: 60 FPS como meta (≤ 16,67 ms por quadro) e 30 FPS como piso
## (≤ 33,33 ms por quadro), medido sobre a chamada de update().

const META_60_FPS_US: float = 16667.0
const PISO_30_FPS_US: float = 33333.0
const AQUECIMENTO: int = 600
const MEDIDOS: int = 600


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


func _rodar(ambiente: String, quadros: int) -> int:
	decoracao.set_environment(ambiente)
	for i in AQUECIMENTO:
		transito.update(1.0 / 60.0, road)
		decoracao.update(1.0 / 60.0, road)

	var inicio: int = Time.get_ticks_usec()
	for i in quadros:
		transito.update(1.0 / 60.0, road)
		decoracao.update(1.0 / 60.0, road)
	return (Time.get_ticks_usec() - inicio) / quadros


func test_frame_budget_on_all_environments() -> void:
	for ambiente in ["PLAINS", "DESERT", "FOREST", "ICE"]:
		var medio_us: float = float(_rodar(ambiente, MEDIDOS))
		assert_float(medio_us).is_less_equal(PISO_30_FPS_US).override_failure_message(
			"SC-024: %s estourou o piso de 30 FPS (%.0f µs/quadro)" % [ambiente, medio_us]
		)
		assert_float(medio_us).is_less_equal(META_60_FPS_US).override_failure_message(
			"SC-024: %s não atingiu a meta de 60 FPS (%.0f µs/quadro)" % [ambiente, medio_us]
		)


## Os dois sistemas estão de fato em operação durante a medição.
func test_systems_are_popular_during_measurement() -> void:
	_rodar("FOREST", 60)
	assert_int(transito.active_count).is_greater(0).override_failure_message(
		"SC-024: sem veículos na medição"
	)
	assert_int(decoracao.active_count).is_greater(0).override_failure_message(
		"SC-024: sem elementos na medição"
	)
