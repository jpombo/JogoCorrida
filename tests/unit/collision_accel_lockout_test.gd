extends GdUnitTestSuite

## Ajuste 4 da SPEC-005 — colisão desconsidera a aceleração: sem isso, quem
## segura o acelera repõe a perda de velocidade no mesmo instante e o jogador
## "volta" à mesma posição logo após ser empurrado para trás.

const BOUNDS_FIXOS := {"left": 248.0, "right": 392.0}
const ACOES: Array[String] = ["accelerate", "brake", "move_left", "move_right"]

var sistema: CollisionSystem
var jogador: PlayerVehicle


func before_test() -> void:
	_soltar_acoes()
	sistema = CollisionSystem.new()
	jogador = PlayerVehicle.new()
	jogador.position = Vector2(320.0, 400.0)
	jogador.controller.speed = 100.0


func after_test() -> void:
	_soltar_acoes()
	jogador.free()
	sistema = null


func _soltar_acoes() -> void:
	for acao in ACOES:
		Input.action_release(acao)


func _npc(categoria_id: String, pos: Vector2) -> TrafficVehicle:
	var npc := TrafficVehicle.new()
	npc.category = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[categoria_id])
	npc.category.size = Vector2(32.0, 48.0)
	npc.position = pos
	npc.state = TrafficVehicle.State.ACTIVE
	return npc


func _bounds(_y: float) -> Dictionary:
	return BOUNDS_FIXOS


## Colisão frontal garantida: NPC exatamente acima do jogador (dy=36 < soma
## das meias-alturas).
func _colidir() -> TrafficVehicle:
	var npc := _npc("passeio", Vector2(320.0, 364.0))
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)
	return npc


func test_collision_arms_accel_lockout_with_configured_duration() -> void:
	var npc := _colidir()
	assert_float(jogador.controller.aceleracao_bloqueada).is_equal(
		GameConfig.collision_accel_lockout_time
	).override_failure_message("Ajuste 4: colisão deve armar o bloqueio da aceleração")
	npc.free()


func test_acceleration_disregarded_while_lockout_active() -> void:
	var npc := _colidir()
	var vel_apos_impacto: float = jogador.controller.speed

	Input.action_press("accelerate")
	# 0,7 s de quadros — dentro do bloqueio configurado (0,8 s).
	for i in 7:
		jogador.controller._process(0.1)
	Input.action_release("accelerate")

	assert_float(jogador.controller.speed).is_less(
		vel_apos_impacto
	).override_failure_message(
		"Ajuste 4: com o bloqueio ativo a aceleração deve ser desconsiderada (velocidade cai, não sobe)"
	)
	npc.free()


func test_acceleration_resumes_after_lockout_expires() -> void:
	var npc := _colidir()
	jogador.controller.aceleracao_bloqueada = 0.0
	var vel_base: float = jogador.controller.speed

	Input.action_press("accelerate")
	jogador.controller._process(0.1)
	Input.action_release("accelerate")

	assert_float(jogador.controller.speed).is_greater(
		vel_base
	).override_failure_message(
		"Expirado o bloqueio, a aceleração deve voltar a valer normalmente"
	)
	npc.free()


func test_brake_still_works_during_lockout() -> void:
	var npc := _colidir()
	jogador.controller.speed = 50.0
	jogador.controller.aceleracao_bloqueada = GameConfig.collision_accel_lockout_time

	Input.action_press("brake")
	jogador.controller._process(0.1)
	Input.action_release("brake")

	# Frenagem: 70 * 0,1 = 7 — muito além da desaceleração natural (15 * 0,1).
	assert_float(jogador.controller.speed).is_less_equal(
		43.01
	).override_failure_message(
		"Ajuste 4: só a aceleração é desconsiderada — a frenagem continua valendo"
	)
	npc.free()


func test_no_collision_acceleration_stays_inert() -> void:
	var npc := _npc("passeio", Vector2(320.0, 100.0))  # longe, sem contato
	sistema.update(1.0 / 60.0, jogador, [npc], _bounds)

	assert_float(jogador.controller.aceleracao_bloqueada).is_zero().override_failure_message(
		"FR-034: sem colisão o bloqueio não pode ser armado"
	)

	jogador.controller.speed = 50.0  # abaixo do teto para a aceleração ter efeito
	var vel_base: float = jogador.controller.speed
	Input.action_press("accelerate")
	jogador.controller._process(0.1)
	Input.action_release("accelerate")
	assert_float(jogador.controller.speed).is_greater(
		vel_base
	).override_failure_message("FR-034: sem colisão a aceleração segue normal")
	npc.free()


func test_lockout_survives_until_expiry_across_frames() -> void:
	var npc := _colidir()
	for i in 4:
		jogador.controller._process(0.1)
	assert_float(jogador.controller.aceleracao_bloqueada).is_greater(
		0.0
	).override_failure_message("Ajuste 4: o bloqueio deve durar a janela configurada")

	for i in 10:
		jogador.controller._process(0.1)
	assert_float(jogador.controller.aceleracao_bloqueada).is_zero().override_failure_message(
		"Ajuste 4: o bloqueio deve expirar após a janela configurada"
	)
	npc.free()


func test_reset_clears_lockout() -> void:
	var npc := _colidir()
	jogador.controller.reset()
	assert_float(jogador.controller.aceleracao_bloqueada).is_zero().override_failure_message(
		"reset() deve limpar o bloqueio da aceleração"
	)
	npc.free()
