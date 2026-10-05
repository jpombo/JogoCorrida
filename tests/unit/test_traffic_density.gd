extends GdUnitTestSuite

## Ajuste 3/4 — densidade de trânsito visível: ao menos `traffic_min_visible`
## NPCs na tela junto ao jogador (sem "lote" nem seca), e nunca mais que o
## máximo do nível de dificuldade do ambiente (Gelo = 5).


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
	GameConfig.current_environment_id = "PLAINS"


func _visiveis() -> int:
	return transito._contar_visiveis()


func test_minimum_visible_npcs_maintained_without_drought() -> void:
	var road := FakeRoad.new()
	road.scroll_speed = GameConfig.max_speed

	# 45 s de partida; conta quadros com menos que o mínimo NA ESTRADA (na tela
	# ou a poucos pixels acima, já entrando) na fase estável (após os ~15 s de
	# enchimento do pipeline).
	var quadros_seca: int = 0
	var quadros_fase_estavel: int = 0
	for i in 2700:
		transito.update(1.0 / 60.0, road)
		if i > 900:
			quadros_fase_estavel += 1
			if transito._contar_na_pista() < GameConfig.traffic_min_visible:
				quadros_seca += 1

	var taxa_seca: float = float(quadros_seca) / float(quadros_fase_estavel)
	assert_float(taxa_seca).is_less(0.05).override_failure_message(
		"Densidade mínima não sustentada: %.1f%% dos quadros com menos de %d visíveis"
		% [taxa_seca * 100.0, GameConfig.traffic_min_visible]
	)
	road.free()


func test_visible_never_exceeds_difficulty_cap_on_ice() -> void:
	GameConfig.current_environment_id = "ICE"  # dificuldade 4 → máximo 5
	var road := FakeRoad.new()
	road.scroll_speed = GameConfig.max_speed

	var pico: int = 0
	for i in 3600:  # 60 s
		transito.update(1.0 / 60.0, road)
		pico = maxi(pico, _visiveis())

	assert_int(pico).is_less_equal(5).override_failure_message(
		"Gelo deve ter no máximo 5 NPCs visíveis; pico observado: %d" % pico
	)
	road.free()


func test_difficulty_cap_comes_from_environment_config() -> void:
	# Teto global de visíveis = 5 em qualquer ambiente (Gelo é o mais difícil
	# e nunca passa de 5 — pedido explícito do ajuste 3/4).
	for ambiente in ["PLAINS", "DESERT", "FOREST", "ICE"]:
		GameConfig.current_environment_id = ambiente
		assert_int(transito._maximo_visivel_atual()).is_equal(5).override_failure_message(
			"Teto de visíveis inesperado em %s" % ambiente
		)
