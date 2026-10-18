extends GdUnitTestSuite

## Separação mínima entre veículos de trânsito no birth (ajuste de gameplay):
## nenhum NPC nasce a menos de `GameConfig.traffic_min_separation` de outro
## ativo, em qualquer eixo, e o spawn é adiado quando não há faixa válida.


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


func before_test() -> void:
	transito = TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	transito.setup(categorias)


func after_test() -> void:
	transito.free()


func test_spawned_vehicles_keep_minimum_separation() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = 80.0

	# 30s de partida com spawns frequentes: nenhum par ativo pode violar a
	# separação mínima nos dois eixos simultaneamente.
	for i in 1800:
		transito.update(1.0 / 60.0, road)

	var s: float = GameConfig.traffic_min_separation
	for i in transito.active_vehicles.size():
		for j in range(i + 1, transito.active_vehicles.size()):
			var a: TrafficVehicle = transito.active_vehicles[i]
			var b: TrafficVehicle = transito.active_vehicles[j]
			var folga_x: float = absf(a.position.x - b.position.x) - (a.category.size.x + b.category.size.x) * 0.5
			var folga_y: float = absf(a.position.y - b.position.y) - (a.category.size.y + b.category.size.y) * 0.5
			assert_bool(folga_x >= s or folga_y >= s).is_true().override_failure_message(
				"Veículos %d e %d colados/sobrepostos (folgaX=%.2f folgaY=%.2f)" % [i, j, folga_x, folga_y]
			)
	road.free()


func test_spawn_is_deferred_when_no_lane_respects_separation() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = 80.0
	GameConfig.traffic_min_separation = 200.0  # impossível em pista de 144px

	for i in 240:
		transito.update(1.0 / 60.0, road)

	# Com separação maior que a pista, no máximo um veículo por "faixa" nasce —
	# e nunca dois colados.
	var s: float = GameConfig.traffic_min_separation
	for i in transito.active_vehicles.size():
		for j in range(i + 1, transito.active_vehicles.size()):
			var a: TrafficVehicle = transito.active_vehicles[i]
			var b: TrafficVehicle = transito.active_vehicles[j]
			var folga_x: float = absf(a.position.x - b.position.x) - (a.category.size.x + b.category.size.x) * 0.5
			var folga_y: float = absf(a.position.y - b.position.y) - (a.category.size.y + b.category.size.y) * 0.5
			assert_bool(folga_x >= s or folga_y >= s).is_true().override_failure_message(
				"Spawn não adiado mesmo sem faixa com separação suficiente"
			)

	GameConfig.traffic_min_separation = 12.0
	road.free()


## Velocidades por categoria (FR-011): um veículo mais rápido NÃO pode ser
## travado por um mais lento que está em OUTRO corredor — o líder só conta
## quando as projeções laterais se intersectam (`folga_x < 0`; ajuste 5).
## Sem isso o trânsito virava comboio e todas as categorias pareciam ter a
## mesma velocidade.
func test_faster_vehicle_is_not_blocked_by_slower_one_in_another_lane() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = 80.0

	var lento := _criar("caminhao", Vector2(272.0, 240.0))   # faixa esquerda, 72 u/s
	var rapido := _criar("esporte", Vector2(368.0, 180.0))   # faixa direita, 96 u/s, 60px acima

	var y_lento0 := lento.position.y
	var y_rapido0 := rapido.position.y
	for i in 60:  # 1s
		transito.update(1.0 / 60.0, road)

	# Sem outro veículo, o deslocamento aparente seria de 16px/s para cima.
	var subida_livre: float = 16.0
	var subida_real: float = y_rapido0 - rapido.position.y
	assert_float(subida_real).is_equal_approx(subida_livre, 0.5).override_failure_message(
		"Esporte travado pelo caminhão de outra faixa: subiu %.2f em vez de %.2f"
		% [subida_real, subida_livre]
	)
	# E o caminhão segue seu próprio deslocamento (afunda 8px/s).
	var descida_real: float = lento.position.y - y_lento0
	assert_float(descida_real).is_equal_approx(8.0, 0.5)
	road.free()


func _criar(id: String, pos: Vector2) -> TrafficVehicle:
	var v: TrafficVehicle
	for candidato in transito.pool:
		if not candidato.is_active():
			v = candidato
			break
	if v == null:
		v = TrafficVehicle.new()
		transito.add_child(v)
		transito.pool.append(v)
	v.activate(transito.categories[id], pos.x, pos.y)
	v.category.size = Vector2(32.0, 48.0)
	v.previous_right_boundary = 392.0
	transito.active_vehicles.append(v)
	return v
