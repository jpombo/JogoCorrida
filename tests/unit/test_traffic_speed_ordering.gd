extends GdUnitTestSuite

## Ajuste 5 — travamento de velocidade entre categorias (FR-007, FR-019):
##
## 1. Colunas nascem e permanecem ordenadas de baixo para cima (lentos embaixo,
##    rápidos em cima) — sem isso o comboio apagava a diferença de velocidade e
##    o caminhão saía da tela na taxa do esporte (4 px/s no máximo).
## 2. Nesse cenário o caminhão livre desce exatamente à taxa da própria
##    categoria, quadro a quadro, sem nenhum freio fantasma.
## 3. A separação retangular também vale DURANTE o movimento, com o limiar
##    size-aware (meias-alturas somadas + `traffic_min_separation`), não só no
##    birth — o limitador antigo de 70 px deixava o caminhão (128 px) grudar no
##    carro da frente com 26 px de sobreposição.


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
var _max_vehicles_original: int


func before_test() -> void:
	transito = TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	transito.setup(categorias)
	_max_vehicles_original = GameConfig.traffic_max_vehicles


func after_test() -> void:
	GameConfig.traffic_max_vehicles = _max_vehicles_original
	transito.free()


## 1 + 2 — em 2 min de partida contínua na velocidade máxima, todo par no mesmo
## corredor (projeções laterais intersectadas) tem o de cima com velocidade de
## categoria maior ou igual à de baixo; e cada caminhão desce quadro a quadro
## exatamente à taxa da própria categoria — livre de qualquer comboio.
func test_columns_keep_speed_order_and_truck_runs_free() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = GameConfig.max_speed

	var violacoes_ordem: int = 0
	var violacoes_caminhao: int = 0
	var pares_verificados: int = 0
	var esperado_caminhao: float = (GameConfig.max_speed - 72.0) / 60.0
	var anterior := {}  # id -> {"y": float, "quadro": int} (pooled ids são reutilizados)
	var caminhoes_observados: int = 0

	for quadro in 7200:
		transito.update(1.0 / 60.0, road)

		for a in transito.active_vehicles.size():
			var va: TrafficVehicle = transito.active_vehicles[a]
			# Taxa de descida livre do caminhão: se um quadro render menos que
			# (estrada - 72), alguém da mesma coluna o estava travando.
			if va.category != null and va.category.id == "caminhao":
				if anterior.has(va.get_instance_id()):
					var reg: Dictionary = anterior[va.get_instance_id()]
					if reg["quadro"] == quadro - 1:
						var dy_real: float = va.position.y - reg["y"]
						if dy_real < -16.0:
							# Reciclagem do pool: mesmo id saiu da tela e nasceu
							# no topo no quadro seguinte (salto de ~700 px) — não é
							# travamento por comboio.
							caminhoes_observados += 1
						elif dy_real < esperado_caminhao - 0.001:
							violacoes_caminhao += 1
				else:
					caminhoes_observados += 1
				anterior[va.get_instance_id()] = {"y": va.position.y, "quadro": quadro}

			for b in range(a + 1, transito.active_vehicles.size()):
				var vb: TrafficVehicle = transito.active_vehicles[b]
				var folga_x: float = (
					absf(va.position.x - vb.position.x)
					- (va.category.size.x + vb.category.size.x) * 0.5
				)
				if folga_x >= 0.0:
					continue  # corredor distinto
				var dy: float = va.position.y - vb.position.y
				if absf(dy) < 0.001:
					continue
				var topo: TrafficVehicle = va if dy < 0.0 else vb
				var base: TrafficVehicle = vb if dy < 0.0 else va
				pares_verificados += 1
				if topo.get_speed() < base.get_speed() - 0.001:
					violacoes_ordem += 1

	assert_int(violacoes_ordem).is_equal(0).override_failure_message(
		"Ajuste 5: %d pares em coluna desordenada (veículo de cima mais lento que o de baixo)"
		% violacoes_ordem
	)
	assert_int(violacoes_caminhao).is_equal(0).override_failure_message(
		"Ajuste 5: caminhão travado por comboio em %d quadros (deveria descer a %.2f px/quadro)"
		% [violacoes_caminhao, esperado_caminhao]
	)
	assert_int(pares_verificados).is_greater(200).override_failure_message(
		"Ajuste 5: só %d pares no mesmo corredor — a verificação foi vazia" % pares_verificados
	)
	assert_int(caminhoes_observados).is_greater_equal(1).override_failure_message(
		"Ajuste 5: nenhum caminhão observado em 2 min — faixa reservada starving as categorias lentas"
	)
	road.free()


## 3 — durante o movimento, um par no mesmo corredor nunca aproxima os centros
## a menos das meias-alturas somadas + `traffic_min_separation` (limiar
## size-aware). O limitador antigo (70 px fixos) permitiria 108 → 70 px aqui,
## com 26 px de sobreposição visual entre caminhão (128 px) e carro (64 px).
func test_size_aware_gap_is_kept_during_movement() -> void:
	var road := FakeRoad.new()
	# Iguais à do caminhão: ele fica parado e o esporte sobe 24 px/s, fechando
	# a distância — cenário em que o limitador trabalha em todo quadro.
	road.scroll_speed = 72.0
	GameConfig.traffic_max_vehicles = 1  # nenhum nascimento durante a medição

	var caminhao := _criar("caminhao", Vector2(320.0, 300.0))
	caminhao.category.size = Vector2(32.0, 128.0)
	var esporte := _criar("esporte", Vector2(320.0, 420.0))
	esporte.category.size = Vector2(32.0, 64.0)

	var min_centros: float = 64.0 + 32.0 + GameConfig.traffic_min_separation  # 108
	var menor_folga: float = INF

	for _quadro in 600:
		transito.update(1.0 / 60.0, road)
		var folga: float = esporte.position.y - caminhao.position.y
		menor_folga = minf(menor_folga, folga)

	assert_float(menor_folga).is_greater_equal(
		min_centros - 0.5
	).override_failure_message(
		"Ajuste 5: centros chegaram a %.2f px (< %.0f) — sobreposição visual durante o movimento"
		% [menor_folga, min_centros]
	)
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
	transito.active_vehicles.append(v)
	return v
