extends GdUnitTestSuite

## SPEC-008 / teste obrigatório H (ciclo de vida — telas) — US1.
## UIManager: um painel por estado (SC-001, SC-017), textos 100% de
## GameConfig (FR-041), indicador alimentado por progress_changed e UI
## observadora — nunca escreve em Track/Fuel/Player/GameState (FR-005).

var ui: UIManager
var track: TrackManager


func before_test() -> void:
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	ui = UIManager.new()
	add_child(ui)
	ui.setup(track, GameState)
	GameState.reset()


func after_test() -> void:
	GameState.reset()
	ui.queue_free()
	track.queue_free()


## H1 — MENU: só o painel de menu visível; indicador escondido; textos da
## config (SC-017: telas reais, não print).
func test_h1_menu() -> void:
	GameState.reset()  # MENU
	assert_bool(ui._painel_menu.visible).is_true()
	assert_bool(ui._painel_pausa.visible).is_false()
	assert_bool(ui._painel_vitoria.visible).is_false()
	assert_bool(ui._painel_gameover.visible).is_false()
	assert_bool(ui._indicador.visible).is_false()
	assert_bool(ui._rotulo_titulo.text == String(GameConfig.ui_strings.get("menu_title", ""))).is_true()
	assert_bool(ui._rotulo_selecao.text == String(GameConfig.ui_strings.get("select_vehicle", ""))).is_true()
	assert_bool(ui._rotulo_iniciar.text == String(GameConfig.ui_strings.get("start_race", ""))).is_true()
	assert_bool(ui._nome_veiculo.text == String(GameConfig.ui_strings.get("vehicle_blue", ""))).is_true()


## H2 — PAUSED: painel de pausa com as 3 opções da config (FR-034).
func test_h2_pausa() -> void:
	GameState.change_state(GameState.State.PAUSED)
	assert_bool(ui._painel_pausa.visible).is_true()
	assert_bool(ui._painel_menu.visible).is_false()
	assert_bool(ui._indicador.visible).is_true()
	assert_int(ui._opcoes_pausa.size()).is_equal(3)
	assert_bool(ui._opcoes_pausa[0].text == String(GameConfig.ui_strings.get("continue_race", ""))).is_true()
	assert_bool(ui._opcoes_pausa[1].text == String(GameConfig.ui_strings.get("restart_race", ""))).is_true()
	assert_bool(ui._opcoes_pausa[2].text == String(GameConfig.ui_strings.get("back_to_menu", ""))).is_true()


## H3 — VICTORY e GAME_OVER: painéis próprios com as opções da config.
## SPEC-009 / FR-020–021 (T014): vitória = [Continuar próxima fase, Voltar
## ao menu] e Game Over = [Voltar ao menu] — "Tentar novamente" removido das
## duas telas (substitui o FR-034 da SPEC-008).
func test_h3_vitoria_e_gameover() -> void:
	GameState.change_state(GameState.State.VICTORY)
	assert_bool(ui._painel_vitoria.visible).is_true()
	assert_int(ui._opcoes_vitoria.size()).is_equal(2)
	assert_bool(ui._opcoes_vitoria[0].text == String(GameConfig.ui_strings.get("continue_next_phase", ""))).is_true()
	assert_bool(ui._opcoes_vitoria[1].text == String(GameConfig.ui_strings.get("back_to_menu", ""))).is_true()

	GameState.change_state(GameState.State.GAME_OVER)
	assert_bool(ui._painel_gameover.visible).is_true()
	assert_bool(ui._painel_vitoria.visible).is_false()
	assert_int(ui._opcoes_gameover.size()).is_equal(1)
	assert_bool(ui._opcoes_gameover[0].text == String(GameConfig.ui_strings.get("back_to_menu", ""))).is_true()
	assert_bool(ui._painel_gameover.get_child(1).text == String(GameConfig.ui_strings.get("game_over", ""))).is_true()


## H4 — PLAYING/READY: nenhum painel de estado; indicador visível.
func test_h4_playing_sem_paineis() -> void:
	GameState.change_state(GameState.State.READY)
	assert_bool(ui._painel_menu.visible).is_false()
	assert_bool(ui._indicador.visible).is_true()

	GameState.change_state(GameState.State.PLAYING)
	assert_bool(ui._painel_menu.visible).is_false()
	assert_bool(ui._painel_pausa.visible).is_false()
	assert_bool(ui._indicador.visible).is_true()


## H5 — indicador: texto e barra vêm do progress_changed (formato da config);
## congela quando o TrackManager para de emitir (pausa — R12).
func test_h5_indicador() -> void:
	GameState.change_state(GameState.State.PLAYING)
	track.update(1.0, 500.0)  # ~0,174 km
	var texto_esperado: String = (
		String(GameConfig.ui_strings.get("distance_format", ""))
		% [track.get_percorrida(), 5.0]
	)
	assert_bool(ui._rotulo_distancia.text == texto_esperado).is_true()
	assert_float(ui._barra.scale.x).is_greater(0.0)
	assert_float(ui._barra.scale.x).is_less_equal(1.0)

	# Pausa: track para de emitir ⇒ o texto permanece idêntico (SC-012).
	var texto_congelado: String = ui._rotulo_distancia.text
	GameState.change_state(GameState.State.PAUSED)
	assert_bool(ui._rotulo_distancia.text == texto_congelado).is_true()


## H6 — UI observadora: transições e progresso não alteram os modelos (FR-005:
## nenhum write em Track/Fuel/Player/GameState além dos donos).
func test_h6_ui_nao_escreve() -> void:
	GameState.change_state(GameState.State.PLAYING)
	track.update(1.0, 100.0)
	var percorrida: float = track.get_percorrida()

	# Simula um ciclo completo de telas via os handlers de estado.
	GameState.change_state(GameState.State.PAUSED)
	GameState.change_state(GameState.State.PLAYING)
	GameState.change_state(GameState.State.VICTORY)
	GameState.change_state(GameState.State.GAME_OVER)
	GameState.reset()

	# O GameState é o único dono das transições; o TrackManager só muda com
	# update/reset próprios — a UI não o tocou.
	assert_float(track.get_percorrida()).is_equal(percorrida)
	assert_bool(track.esta_concluido()).is_false()


## H7 — setup idempotente (H4/SC-012): reconectar não duplica sinal.
func test_h7_setup_idempotente() -> void:
	var antes: int = GameState.state_changed.get_connections().size()
	ui.setup(track, GameState)
	ui.setup(track, GameState)
	var depois: int = GameState.state_changed.get_connections().size()
	assert_int(depois).is_equal(antes)
