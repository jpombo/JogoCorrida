extends GdUnitTestSuite

## SPEC-005 / T040 — hitboxes independentes dos sprites (FR-006–FR-008, SC-009):
## a área física vem exclusivamente da configuração; trocar a dimensão visual
## do veículo não muda onde o contato acontece; categorias distintas diferem
## apenas pela área configurada.

var sistema: CollisionSystem
var jogador: PlayerVehicle


func before_test() -> void:
	sistema = CollisionSystem.new()
	jogador = PlayerVehicle.new()
	jogador.position = Vector2(320.0, 400.0)


func after_test() -> void:
	jogador.free()
	sistema = null


func _npc(pos: Vector2, categoria_id: String, size_visual: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = size_visual  # "sprite trocado": dimensão visual medida muda
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func test_player_hitbox_comes_from_config_not_sprite() -> void:
	var caixa := sistema.player_hitbox(jogador)
	assert_vector(caixa.size).is_equal(GameConfig.player_hitbox_size).override_failure_message(
		"FR-006: hitbox do jogador não veio da configuração"
	)
	assert_vector(caixa.get_center()).is_equal(jogador.position)


func test_npc_hitbox_unchanged_by_sprite_resize() -> void:
	# US7-CA2/SC-009: troca de sprite por dimensão distinta → mesma hitbox,
	# mesmos resultados de colisão nas mesmas condições relativas.
	var npc_a := _npc(Vector2(320.0, 364.0), "passeio", Vector2(32.0, 48.0))
	var npc_b := _npc(Vector2(320.0, 364.0), "passeio", Vector2(64.0, 96.0))
	assert_vector(sistema.npc_hitbox(npc_a).size).is_equal(sistema.npc_hitbox(npc_b).size).override_failure_message(
		"FR-008: redimensionar o sprite alterou a hitbox"
	)

	var eventos: Array = []
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	jogador.controller.speed = 100.0
	sistema.update(1.0 / 60.0, jogador, [npc_a], Callable(self, "_bounds"))
	jogador.controller.speed = 100.0
	sistema = CollisionSystem.new()
	sistema.collision_occurred.connect(func(d): eventos.append(d))
	jogador.position = Vector2(320.0, 400.0)
	sistema.update(1.0 / 60.0, jogador, [npc_b], Callable(self, "_bounds"))

	assert_int(eventos.size()).is_equal(2)
	assert_int(eventos[0].tipo).is_equal(eventos[1].tipo).override_failure_message(
		"SC-009: troca de sprite mudou o resultado da colisão"
	)
	npc_a.free()
	npc_b.free()


func test_category_hitboxes_define_contact_area() -> void:
	# US7-CA3: caminhão vs. passeio diferem apenas pela área configurada;
	# a hitbox usada é a da categoria.
	var caminhao := _npc(Vector2(320.0, 340.0), "caminhao", Vector2(40.0, 80.0))
	var passeio := _npc(Vector2(320.0, 340.0), "passeio", Vector2(32.0, 48.0))
	assert_vector(sistema.npc_hitbox(caminhao).size).is_equal(GameConfig.NPC_HITBOX_SIZES["caminhao"])
	assert_vector(sistema.npc_hitbox(passeio).size).is_equal(GameConfig.NPC_HITBOX_SIZES["passeio"])
	caminhao.free()
	passeio.free()


func _bounds(_y: float) -> Dictionary:
	return {"left": 248.0, "right": 392.0}
