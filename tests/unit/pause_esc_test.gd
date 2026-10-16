extends GdUnitTestSuite

## Regressão — menu de pausa por ESC (SPEC-008 FR-034, contracts/
## ui_commands.md §3): o MESMO Escape que pausou no quadro PLAYING → PAUSED
## não pode retomar nesse mesmo quadro — `is_action_just_pressed` vale pelo
## quadro inteiro e a UI processa DEPOIS do GameplayManager na árvore. Sem a
## guarda de quadro nos dois nós a pausa e a retomada aconteciam juntas e o
## painel de pausa (com "Continuar", "Reiniciar" e "Voltar ao menu") nunca
## era desenhado. A guarda é por quadro de entrada em PAUSED/PLAYING, então o
## resultado não depende da ordem de processamento entre os dois nós.

var _ui: UIManager
var _track: TrackManager
var _continuar: int = 0


func before_test() -> void:
	GameState.reset()
	_track = TrackManager.new()
	_track.setup(5.0)
	_track.reset()
	_ui = UIManager.new()
	add_child(_ui)
	_ui.setup(_track, GameState)
	# Input 100% manual (padrão dos testes de UI): os handlers são chamados à
	# mão, sem o `_process` automático disputando o mesmo quadro.
	_ui.set_process(false)
	_continuar = 0
	# Espelha o wiring do `_ready` do orquestrador: o handler da UI vira
	# retomada de estado observável (gameplay_manager.gd `_on_continue_race`).
	_ui.continue_race.connect(func(): GameState.resume_game())
	_ui.continue_race.connect(func(): _continuar += 1)
	Input.action_release("ui_cancel")
	GameState.change_state(GameState.State.PLAYING)


func after_test() -> void:
	Input.action_release("ui_cancel")
	GameState.reset()
	_ui.queue_free()
	_track.queue_free()


## 1 — O ESC que pausou não retoma no MESMO quadro: pausa → UI no mesmo
## quadro ⇒ estado PAUSED, painel visível e zero emissões de `continue_race`.
func test_01_esc_no_quadro_da_pausa_nao_retoma() -> void:
	Input.action_press("ui_cancel")
	GameState.pause_game()  # o que o GameplayManager faz no mesmo quadro
	_ui._process(0.0)  # UI roda depois do manager na ordem da árvore

	assert_int(_continuar).is_equal(0).override_failure_message(
		"ESC retomou no MESMO quadro da pausa — o painel de pausa nunca é desenhado"
	)
	assert_int(GameState.current_state).is_equal(GameState.State.PAUSED)
	assert_bool(_ui._painel_pausa.visible).is_true().override_failure_message(
		"PAUSED deveria manter o painel de pausa visível (opção 'Voltar ao menu' incluída)"
	)
	Input.action_release("ui_cancel")


## 2 — O ESC em um quadro POSTERIOR retoma normalmente: solta, atravessa a
## borda de quadro e pressiona de novo ⇒ `continue_race` 1× e estado PLAYING.
func test_02_esc_em_quadro_posterior_retoma() -> void:
	Input.action_press("ui_cancel")
	GameState.pause_game()
	_ui._process(0.0)
	Input.action_release("ui_cancel")

	await get_tree().process_frame  # rearma o "just" e afasta o quadro da pausa

	Input.action_press("ui_cancel")
	_ui._process(0.0)
	assert_int(_continuar).is_equal(1).override_failure_message(
		"ESC em quadro posterior deveria retomar a corrida 1×"
	)
	assert_int(GameState.current_state).is_equal(GameState.State.PLAYING)
	assert_bool(_ui._painel_pausa.visible).is_false()
	Input.action_release("ui_cancel")


## 3 — Lado do orquestrador: o ESC no MESMO quadro da virada para PLAYING
## (o par da guarda da UI) não pausa — o toggle fica estável em qualquer
## ordem de processamento entre GameplayManager e UIManager.
func test_03_esc_no_quadro_da_largada_nao_pausa() -> void:
	var gm := GameplayManager.new()
	gm.game_state.state_changed.connect(gm._on_state_changed)  # espelha _ready

	# PAUSED → PLAYING no mesmo quadro (sem o reset READY → PLAYING).
	GameState.change_state(GameState.State.PAUSED)
	GameState.begin_playing()
	Input.action_press("ui_cancel")
	gm._processar_playing(1.0 / 60.0)

	assert_int(GameState.current_state).is_equal(GameState.State.PLAYING)\
		.override_failure_message(
			"ESC pausou no MESMO quadro da virada para PLAYING — guardas fora de sincronia"
		)
	Input.action_release("ui_cancel")

	# Quadro seguinte: o ESC volta a pausar normalmente.
	await get_tree().process_frame
	Input.action_press("ui_cancel")
	gm._processar_playing(1.0 / 60.0)
	assert_int(GameState.current_state).is_equal(GameState.State.PAUSED)\
		.override_failure_message("ESC em quadro posterior deveria pausar a corrida")
	Input.action_release("ui_cancel")
	gm.free()
