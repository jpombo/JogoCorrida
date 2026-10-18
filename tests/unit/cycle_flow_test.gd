extends GdUnitTestSuite

## SPEC-009 / T016 (US2) — Fluxo completo de progressão no GameplayManager
## (contracts/environment_cycle.md §2–§3): vitória registra o avanço ANTES
## do estado VICTORY; `_on_continue_next_phase` consome o estado avançado
## (ambiente % 4 + fator de ciclo, modo mantido — garantia 2); derrota zera
## o ciclo corrente e preserva ciclos (FR-023); `_reset_corrida`/largada não
## tocam no progresso (R10); regressão R12 — manager sintético sem `_ready`
## continua íntegro.

var gm: GameplayManager
var _vitorias: int = 0
var _derrotas: int = 0
var _ambiente_original: String = "PLAINS"


func before_test() -> void:
	_vitorias = 0
	_derrotas = 0
	_ambiente_original = String(GameConfig.current_environment_id)
	gm = _montar_gm()
	GameState.reset()


func after_test() -> void:
	GameConfig.current_environment_id = _ambiente_original
	_desmontar_gm(gm)
	GameState.reset()


## F1 — vitória registra o avanço ANTES da transição: posição+1 na
## sequência e vitória do ciclo contabilizada (FR-019, SC-016).
func test_f1_vitoria_registra_avanco() -> void:
	_preparar_vitoria()
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)
	assert_int(gm.progresso.posicao).is_equal(1)
	assert_int(gm.progresso.vitorias_ciclo).is_equal(1)
	assert_int(gm.progresso.ciclos_concluidos).is_equal(0)


## F2 — 4ª vitória conclui o ciclo: ciclos+1, vitorias=0, posição 0 e
## `continue_next_phase` aplica o bônus do ciclo e o ambiente PLAINS
## (FR-022, SC-015/SC-016).
func test_f2_quarta_vitoria_novo_ciclo_e_bonus() -> void:
	for i in 4:
		_preparar_vitoria()
		GameState.change_state(GameState.State.PLAYING)
		gm._avaliar_transicoes()
		GameState.change_state(GameState.State.MENU)  # limpa a vitória anterior

	assert_int(gm.progresso.ciclos_concluidos).is_equal(1)
	assert_int(gm.progresso.vitorias_ciclo).is_equal(0)
	assert_int(gm.progresso.posicao).is_equal(0)

	gm._on_continue_next_phase()

	assert_str(GameConfig.current_environment_id).is_equal("PLAINS")
	var incremento: float = GameConfig.difficulty_cycle_bonus_increment
	assert_float(gm.dificuldade.fator_ciclo()).is_equal_approx(
		1.0 + incremento, 0.0000001
	)


## F3 — continuação mantém o modo selecionado e prepara a corrida do zero
## (garantia 2 do contrato): tanque na carga inicial e distância zerada.
func test_f3_continuacao_modo_mantido_corrida_do_zero() -> void:
	gm.dificuldade.definir_modo("challenge")
	gm._reset_corrida()
	gm.fuel_system.update(10.0, 100.0)  # suja o tanque

	gm._on_continue_next_phase()

	assert_str(gm.dificuldade.get_modo()).is_equal("challenge")
	assert_float(gm.fuel_system.get_atual()).is_equal(gm.fuel_system.get_capacidade())
	assert_float(gm.track_manager.get_percorrida()).is_equal(0.0)
	assert_int(GameState.current_state).is_equal(GameState.State.READY)


## F4 — derrota zera o ciclo corrente e preserva ciclos concluídos; a
## próxima largada pelo menu nasce em PLAINS (FR-023, R9).
func test_f4_derrota_zera_ciclo_preserva_ciclos() -> void:
	# Avança um ciclo completo e começa o segundo.
	for i in 4:
		gm.progresso.registra_vitoria()
	gm.progresso.registra_vitoria()  # posicao=1, vitorias=1 no 2º ciclo

	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 0.0
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)
	assert_int(gm.progresso.posicao).is_equal(0)
	assert_int(gm.progresso.vitorias_ciclo).is_equal(0)
	assert_int(gm.progresso.ciclos_concluidos).is_equal(1)  # preservado

	# Próxima largada: PLAINS e bônus do ciclo preservado.
	gm._on_start_race()
	assert_str(GameConfig.current_environment_id).is_equal("PLAINS")
	var incremento: float = GameConfig.difficulty_cycle_bonus_increment
	assert_float(gm.dificuldade.fator_ciclo()).is_equal_approx(
		1.0 + incremento, 0.0000001
	)


## F5 — `_reset_corrida` (R10/SC-012) não zera progresso nem fatores: o
## reinício da pausa mantém a mesma corrida e o mesmo bônus de ciclo.
func test_f5_reset_nao_zera_progresso() -> void:
	gm.progresso.registra_vitoria()
	gm.progresso.registra_vitoria()
	gm.dificuldade.aplicar_fator_ciclo(gm.progresso.fator_ciclo())

	gm._reset_corrida()

	assert_int(gm.progresso.posicao).is_equal(2)
	assert_int(gm.progresso.vitorias_ciclo).is_equal(2)
	assert_float(gm.dificuldade.fator_ciclo()).is_equal(1.0)  # ciclo 1: sem bônus


## F6 — largada do menu (menu → READY) sincroniza ambiente + fator de ciclo
## e injeta os fatores nos sistemas (FR-006, SC-017: modo×ciclo por corrida).
func test_f6_largada_injeta_fatores_com_ciclo() -> void:
	for i in 4:
		gm.progresso.registra_vitoria()  # 1 ciclo completo → fator 1,002
	gm.dificuldade.definir_modo("relaxing")

	gm._on_start_race()

	var incremento: float = GameConfig.difficulty_cycle_bonus_increment
	var esperado: float = 1.0 * (1.0 + incremento)  # relaxing × fator de ciclo
	assert_float(gm.fuel_system.fator_velocidade).is_equal_approx(esperado, 0.0000001)
	assert_float(gm.player_vehicle.controller.fator_dificuldade).is_equal_approx(
		esperado, 0.0000001
	)
	assert_str(GameConfig.current_environment_id).is_equal("PLAINS")


## Prepara as condições de vitória (padrão de track_finish_test C7): banda
## de chegada cruzada e combustível positivo.
func _preparar_vitoria() -> void:
	gm.track_manager.setup(5.0)
	gm.track_manager.reset()
	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()
	gm.track_layer.criar_marcadores(400.0, 0.05)
	gm.track_layer.banda_chegada.position.y = 430.0


## Contadores dos sinais de encerramento.
func _contar_vitoria() -> void:
	_vitorias += 1


func _contar_derrota() -> void:
	_derrotas += 1


## Monta o gerenciador sintético no padrão das suítes legadas (R12): fora da
## árvore de cena, sem `_ready` — só os campos que os caminhos exercitados
## consultam. `progresso`/`dificuldade` nascem nos field initializers, como
## no jogo real.
func _montar_gm() -> GameplayManager:
	var gerente := GameplayManager.new()
	gerente.game_state = GameState
	gerente.fuel_system = FuelSystem.new()
	gerente.track_manager = TrackManager.new()
	gerente.track_layer = TrackMarkers.new()
	gerente.player_vehicle = PlayerVehicle.new()
	# `sprite` é `@onready` — fora da árvore não resolve sozinho; o preparo
	# da corrida troca o sprite na largada (`_aplicar_sprite_selecionado`).
	gerente.player_vehicle.sprite = Sprite2D.new()
	gerente.items_layer = FuelCanManager.new()
	gerente.items_layer.setup()
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	gerente.race_won.connect(_contar_vitoria)
	gerente.race_lost.connect(_contar_derrota)
	return gerente


func _desmontar_gm(gerente: GameplayManager) -> void:
	gerente.fuel_system.free()
	gerente.track_manager.free()
	gerente.track_layer.free()
	gerente.player_vehicle.free()
	gerente.items_layer.free()
	gerente.free()
