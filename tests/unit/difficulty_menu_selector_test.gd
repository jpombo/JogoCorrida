extends GdUnitTestSuite

## SPEC-009 / T031 (FR-016, FR-017, US1/AC9) — Seletor de modo no menu de 3
## linhas: navegação `wrapi(0, 3)` com o destaque acompanhando a linha
## (0 = veículo, 1 = modo, 2 = iniciar), rótulo inicial "Modo: Normal" (padrão
## da config), `ui_accept` na linha 1 emite APENAS `select_next_mode` (a UI só
## emite — o estado do modo vive no DifficultyManager, contracts/
## ui_commands.md §1) e `atualizar_modo` reflete o novo rótulo (FR-017).

var ui: UIManager
var track: TrackManager
var _emitidos_modo: int = 0
var _emitidos_iniciar: int = 0
var _emitidos_veiculo: int = 0


func before_test() -> void:
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	GameState.reset()
	ui = UIManager.new()
	add_child(ui)
	ui.setup(track, GameState)
	# Input 100% manual: sem o `_process` automático disputando o mesmo
	# `is_action_just_pressed` do quadro com o `_process_menu` chamado à mão
	# (o processamento em árvore repetiria a navegação no mesmo frame).
	ui.set_process(false)
	_emitidos_modo = 0
	_emitidos_iniciar = 0
	_emitidos_veiculo = 0
	ui.select_next_mode.connect(func(): _emitidos_modo += 1)
	ui.start_race.connect(func(): _emitidos_iniciar += 1)
	ui.select_next_vehicle.connect(func(): _emitidos_veiculo += 1)


func after_test() -> void:
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_accept")
	GameState.reset()
	ui.queue_free()
	track.queue_free()


## Pressiona a ação, processa um quadro do menu e solta; aguarda a borda de
## frame para que `is_action_just_pressed` rearme antes do próximo toque da
## MESMA ação (o "just" vale pelo quadro corrente).
func _pressionar(acao: String) -> void:
	Input.action_press(acao)
	ui._process_menu()
	Input.action_release(acao)
	await get_tree().process_frame


## 1 — Navegação com wraparound nas 3 linhas e destaque acompanhando.
func test_01_navegacao_wrapi_tres_linhas() -> void:
	ui._opcao_menu = 0
	ui._posicionar_destaque_menu()

	await _pressionar("ui_up")
	assert_int(ui._opcao_menu).is_equal(2).override_failure_message(
		"FR-016: ui_up na linha 0 não envolveu para a linha 2 (wrapi(0,3))"
	)
	assert_bool(absf(ui._destaque_menu.position.y - 284.0) < 0.5).is_true()\
		.override_failure_message("FR-016: destaque não acompanhou a linha Iniciar")

	await _pressionar("ui_down")
	assert_int(ui._opcao_menu).is_equal(0).override_failure_message(
		"FR-016: ui_down na linha 2 não envolveu para a linha 0 (wrapi(0,3))"
	)
	assert_bool(absf(ui._destaque_menu.position.y - 164.0) < 0.5).is_true()\
		.override_failure_message("FR-016: destaque não voltou para a linha de veículo")

	await _pressionar("ui_down")
	assert_int(ui._opcao_menu).is_equal(1).override_failure_message(
		"FR-016: ui_down não avançou da linha 0 para a linha 1 (Modo)"
	)
	assert_bool(absf(ui._destaque_menu.position.y - 244.0) < 0.5).is_true()\
		.override_failure_message("FR-016: destaque não acompanhou a linha Modo")

	await _pressionar("ui_down")
	assert_int(ui._opcao_menu).is_equal(2)
	await _pressionar("ui_down")
	assert_int(ui._opcao_menu).is_equal(0)


## 2 — Rótulo da linha Modo: padrão da config no nascimento do menu e
## `atualizar_modo` refletindo a troca (FR-017).
func test_02_rotulo_modo_inicial_e_atualizacao() -> void:
	var rotulo_padrao: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("mode_label", "")),
		String(GameConfig.ui_strings.get("mode_normal", "")),
	]
	assert_str(ui._rotulo_modo.text).is_equal(rotulo_padrao).override_failure_message(
		"FR-016: rótulo inicial da linha Modo não é o padrão da config — veio '%s'"
			% ui._rotulo_modo.text
	)

	ui.atualizar_modo(String(GameConfig.ui_strings.get("mode_challenge", "")))
	var rotulo_desafio: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("mode_label", "")),
		String(GameConfig.ui_strings.get("mode_challenge", "")),
	]
	assert_str(ui._rotulo_modo.text).is_equal(rotulo_desafio).override_failure_message(
		"FR-017: atualizar_modo não refletiu o novo rótulo — veio '%s'" % ui._rotulo_modo.text
	)


## 3 — `ui_accept` depende da linha ativa: linha 1 emite só
## `select_next_mode`; linha 2 emite `start_race`; linha 0 alterna veículo
## (FR-016/US1-AC9 — seleção refletida antes da próxima corrida).
func test_03_ui_accept_depende_da_linha() -> void:
	ui._opcao_menu = 1
	await _pressionar("ui_accept")
	assert_int(_emitidos_modo).is_equal(1).override_failure_message(
		"FR-016: ui_accept na linha Modo não emitiu select_next_mode"
	)
	assert_int(_emitidos_iniciar).is_zero().override_failure_message(
		"FR-016: ui_accept na linha Modo emitiu start_race junto"
	)
	assert_int(_emitidos_veiculo).is_zero().override_failure_message(
		"FR-016: ui_accept na linha Modo emitiu select_next_vehicle junto"
	)

	ui._opcao_menu = 2
	await _pressionar("ui_accept")
	assert_int(_emitidos_iniciar).is_equal(1).override_failure_message(
		"FR-016: ui_accept na linha Iniciar não emitiu start_race"
	)
	assert_int(_emitidos_modo).is_equal(1).override_failure_message(
		"FR-016: linha Iniciar emitiu select_next_mode a mais"
	)

	ui._opcao_menu = 0
	await _pressionar("ui_accept")
	assert_int(_emitidos_veiculo).is_equal(1).override_failure_message(
		"FR-016: ui_accept na linha de veículo não emitiu select_next_vehicle"
	)
	assert_int(_emitidos_iniciar).is_equal(1).override_failure_message(
		"FR-016: linha de veículo emitiu start_race a mais"
	)
