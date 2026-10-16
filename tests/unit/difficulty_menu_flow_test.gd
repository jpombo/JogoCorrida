extends GdUnitTestSuite

## SPEC-009 / T034 (FR-016, US1/AC9) — Composição do seletor no orquestrador:
## o sinal `select_next_mode` → `_on_select_next_mode()` (wiring espelhado do
## `_ready`, contracts/ui_commands.md §5) cicla o DifficultyManager na ordem
## ORDEM_CICLO e devolve o rótulo à UI via `_rotulo_modo()` (mapeia `mode_<id>`
## de GameConfig.ui_strings — a UI só exibe). Guardas de `dificuldade == null`
## e `ui_root` nulo não quebram a composição; as peças (UI, manager) são
## testadas isoladamente em difficulty_menu_selector_test e
## difficulty_manager_test — aqui costura as duas pontas.

var _gm: GameplayManager
var _ui: UIManager
var _track: TrackManager


func before_test() -> void:
	GameState.reset()
	_track = TrackManager.new()
	_track.setup(5.0)
	_track.reset()
	_ui = UIManager.new()
	add_child(_ui)
	_ui.setup(_track, GameState)
	# Input 100% manual (padrão T031): nenhum quadro disputa o estado do menu.
	_ui.set_process(false)
	_gm = GameplayManager.new()
	_gm.game_state = GameState
	_gm.ui_root = _ui
	_gm.dificuldade = DifficultyManager.new()
	_gm.dificuldade.definir_modo("normal")
	# Espelha o wiring do `_ready` do orquestrador (linha de sinal que o
	# teste sintético não executa) para exercitar a cadeia real de emit→handler.
	_ui.select_next_mode.connect(_gm._on_select_next_mode)


func after_test() -> void:
	_gm = null
	_ui.queue_free()
	_track.queue_free()
	GameState.reset()


## Rótulo esperado da linha "Modo": "Modo: <nome>" 100% de ui_strings.
func _rotulo_esperado(chave: String) -> String:
	return "%s: %s" % [
		String(GameConfig.ui_strings.get("mode_label", "")),
		String(GameConfig.ui_strings.get(chave, "")),
	]


## 1 — Cadeia sinal → orquestrador → UI: normal → desafio → relaxante →
## normal (wrap de ORDEM_CICLO), com o rótulo acompanhando a cada troca e o
## mapeamento `mode_<id>` de `_rotulo_modo()` nunca vazio (FR-016/US1-AC9).
func test_01_ciclo_do_modo_e_rotulo_via_orquestrador() -> void:
	for chave in ["mode_normal", "mode_challenge", "mode_relaxing"]:
		assert_str(String(GameConfig.ui_strings.get(chave, ""))).is_not_empty()
		assert_str(_gm._rotulo_modo()).is_not_empty().override_failure_message(
			"FR-016: _rotulo_modo() devolveu vazio para '%s' — chave mode_* ausente"
				% chave
		)

	_ui.select_next_mode.emit()
	assert_str(_gm.dificuldade.get_modo()).is_equal("challenge").override_failure_message(
		"FR-016: 1ª emissão de select_next_mode não ciclou normal → challenge"
	)
	assert_str(_ui._rotulo_modo.text).is_equal(_rotulo_esperado("mode_challenge"))\
		.override_failure_message(
			"US1/AC9: rótulo não acompanhou o ciclo — esperado '%s', veio '%s'"
				% [_rotulo_esperado("mode_challenge"), _ui._rotulo_modo.text]
		)

	_ui.select_next_mode.emit()
	assert_str(_gm.dificuldade.get_modo()).is_equal("relaxing").override_failure_message(
		"FR-016: 2ª emissão não ciclou challenge → relaxing"
	)
	assert_str(_ui._rotulo_modo.text).is_equal(_rotulo_esperado("mode_relaxing"))\
		.override_failure_message(
			"US1/AC9: rótulo não acompanhou o ciclo — esperado '%s', veio '%s'"
				% [_rotulo_esperado("mode_relaxing"), _ui._rotulo_modo.text]
		)

	_ui.select_next_mode.emit()
	assert_str(_gm.dificuldade.get_modo()).is_equal("normal").override_failure_message(
		"FR-016: 3ª emissão não envolveu relaxing → normal (wrap de ORDEM_CICLO)"
	)
	assert_str(_ui._rotulo_modo.text).is_equal(_rotulo_esperado("mode_normal"))\
		.override_failure_message(
			"US1/AC9: rótulo não acompanhou o wrap — esperado '%s', veio '%s'"
				% [_rotulo_esperado("mode_normal"), _ui._rotulo_modo.text]
		)

	# Mapeamento completo dos 3 modos direto no orquestrador (FR-017/§VI).
	_gm.dificuldade.definir_modo("relaxing")
	assert_str(_gm._rotulo_modo()).is_equal(
		String(GameConfig.ui_strings.get("mode_relaxing", ""))
	)
	_gm.dificuldade.definir_modo("challenge")
	assert_str(_gm._rotulo_modo()).is_equal(
		String(GameConfig.ui_strings.get("mode_challenge", ""))
	)


## 2 — Guardas: `ui_root` nulo não impede a troca de modo (que é do
## manager, não da UI); `dificuldade == null` retorna sem efeito, sem crash,
## e `_rotulo_modo()` devolve "" (FR-016, contracts/ui_commands.md §1).
func test_02_guardas_de_nulo_na_composicao() -> void:
	_gm.ui_root = null
	_gm._on_select_next_mode()
	assert_str(_gm.dificuldade.get_modo()).is_equal("challenge").override_failure_message(
		"FR-016: com ui_root nulo a troca de modo deveria continuar no manager"
	)

	_gm.ui_root = _ui
	var rotulo_antes: String = _ui._rotulo_modo.text
	_gm.dificuldade = null
	_gm._on_select_next_mode()
	assert_str(_gm._rotulo_modo()).is_equal("").override_failure_message(
		"FR-016: com dificuldade nula _rotulo_modo() deveria devolver ''"
	)
	assert_str(_ui._rotulo_modo.text).is_equal(rotulo_antes).override_failure_message(
		"FR-016: com dificuldade nula o rótulo da UI não deveria mudar"
	)
