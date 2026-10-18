extends GdUnitTestSuite

## T047 / FR-026, FR-049, FR-062, SC-018 — nenhum objeto do SPEC-004 participa
## de física nem detecta contato: sem corpo, sem sinal de contato, sem método de
## resolução, inclusive durante uma partida contínua.

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


## Varre a subárvore procurando qualquer nó de física ou de colisão.
func _corpos_encontrados(no: Node) -> Array:
	var achados: Array = []
	for filho in no.get_children():
		if filho is PhysicsBody2D or filho is Area2D:
			achados.append(filho.get_class())
		achados.append_array(_corpos_encontrados(filho))
	return achados


func test_traffic_vehicle_has_no_physics() -> void:
	# Tipado como Node: o analisador do Godot rejeita `is PhysicsBody2D` quando o
	# tipo estático já é TrafficVehicle (Sprite2D), mas a checagem precisa existir.
	var veiculo: Node = TrafficVehicle.new()
	assert_bool(veiculo is PhysicsBody2D).is_false().override_failure_message(
		"FR-026: TrafficVehicle é PhysicsBody2D"
	)
	assert_bool(veiculo.has_signal("body_entered")).is_false().override_failure_message(
		"FR-026: TrafficVehicle expõe body_entered"
	)
	assert_bool(veiculo.has_method("resolve_collision")).is_false().override_failure_message(
		"FR-026: TrafficVehicle resolve colisão"
	)
	assert_bool(veiculo.has_method("apply_impulse")).is_false().override_failure_message(
		"FR-026: TrafficVehicle aplica impulso"
	)
	veiculo.free()


func test_decoration_element_has_no_physics() -> void:
	var elemento: Node = DecorationElement.new()
	assert_bool(elemento is PhysicsBody2D).is_false().override_failure_message(
		"FR-049: DecorationElement é PhysicsBody2D"
	)
	assert_bool(elemento.has_signal("body_entered")).is_false().override_failure_message(
		"FR-049: DecorationElement expõe body_entered"
	)
	assert_bool(elemento.has_method("resolve_collision")).is_false().override_failure_message(
		"FR-049: DecorationElement resolve colisão"
	)
	elemento.free()


func test_managers_have_no_contact_signals() -> void:
	var transito := TrafficManager.new()
	var decoracao := DecorationManager.new()

	for sinal in ["body_entered", "area_entered", "body_shape_entered"]:
		assert_bool(transito.has_signal(sinal)).is_false().override_failure_message(
			"FR-026: TrafficManager expõe %s" % sinal
		)
		assert_bool(decoracao.has_signal(sinal)).is_false().override_failure_message(
			"FR-049: DecorationManager expõe %s" % sinal
		)

	transito.free()
	decoracao.free()


## Partida contínua: depois de 20 s com os dois sistemas em cena, a subárvore
## continua sem qualquer nó de física e os pools estão populados.
func test_continuous_run_has_no_collision_anywhere() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = 80.0

	var transito := TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	transito.setup(categorias)

	var decoracao := DecorationManager.new()
	decoracao.setup(GameConfig.DECORATION_LIBRARIES)
	decoracao.set_environment("FOREST")

	for i in 1200:
		transito.update(1.0 / 60.0, road)
		decoracao.update(1.0 / 60.0, road)

	assert_int(transito.active_count).is_greater(0).override_failure_message(
		"SC-018: preciso de veículos na partida contínua"
	)
	assert_int(decoracao.active_count).is_greater(0).override_failure_message(
		"SC-018: preciso de elementos na partida contínua"
	)

	assert_array(_corpos_encontrados(transito)).is_empty().override_failure_message(
		"FR-026: nó de física apareceu no pool de trânsito"
	)
	assert_array(_corpos_encontrados(decoracao)).is_empty().override_failure_message(
		"FR-049: nó de física apareceu no pool de decoração"
	)

	transito.free()
	decoracao.free()
	road.free()
