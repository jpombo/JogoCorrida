extends GdUnitTestSuite

## SPEC-012 / T006 — Painel de configurações + menu de 4 linhas (RED contra
## contracts/settings_menu_commands.md §1–3, RF-001/RF-002/FR-001):
## - menu principal ganha a linha 2 "Configurações" (ui_accept emite
##   open_settings e NÃO start_race; "Iniciar corrida" passa ao índice 3);
## - o painel só exibe e emite (settings_audio_alterado /
##   settings_resolucao_alterada) — persistência é do GameplayManager;
## - estado inicial reflete o PreferencesManager recebido no setup (3º
##   parâmetro opcional) e, sem preferências, os defaults do GameConfig;
## - fechar (aceitar "Voltar ao menu" ou ui_cancel) emite close_settings e
##   devolve o menu navegável.

var ui: UIManager
var track: TrackManager
var _pref: PreferencesManager

var _abertos: int = 0
var _fechados: int = 0
var _audio_emittido: Array = []
var _resolucao_emittida: Array = []
var _emitidos_iniciar: int = 0


func before_test() -> void:
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	GameState.reset()
	_pref = PreferencesManager.new("user://_teste_settings_menu.json")
	ui = UIManager.new()
	add_child(ui)
	ui.setup(track, GameState, _pref)
	ui.set_process(false)
	_abertos = 0
	_fechados = 0
	_audio_emittido = []
	_resolucao_emittida = []
	_emitidos_iniciar = 0
	ui.open_settings.connect(func(): _abertos += 1)
	ui.close_settings.connect(func(): _fechados += 1)
	ui.settings_audio_alterado.connect(func(ativo: bool): _audio_emittido.append(ativo))
	ui.settings_resolucao_alterada.connect(func(res: Vector2i):
		_resolucao_emittida.append(res))
	ui.start_race.connect(func(): _emitidos_iniciar += 1)


func after_test() -> void:
	for acao in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
		Input.action_release(acao)
	GameState.reset()
	ui.queue_free()
	track.queue_free()
	_pref = null


## Pressiona, roteia um quadro pelo dispatcher real da UI (MENU → menu ou
## painel de configurações conforme o estado interno), solta e espera a borda
## de frame rearmar `is_action_just_pressed`.
func _pressionar(acao: String) -> void:
	Input.action_press(acao)
	ui._process(0.0)
	Input.action_release(acao)
	await get_tree().process_frame


## Abre o painel pela navegação natural: linha 2 + ui_accept.
func _abrir_configuracoes() -> void:
	ui._opcao_menu = 2
	await _pressionar("ui_accept")


## 1 — Menu de 4 linhas: linha 2 "Configurações" e ui_accept abrindo o
## painel em vez de start_race (contract §2).
func test_01_menu_quarta_linha_abre_configuracoes() -> void:
	assert_str(ui._rotulo_configuracoes.text).is_equal(
		String(GameConfig.ui_strings.get("settings", ""))
	).override_failure_message("FR-001: linha 'Configurações' ausente/errada no menu")
	assert_int(ui._opcoes_menu.size()).is_equal(4).override_failure_message(
		"FR-001: o menu principal deve ter 4 opções"
	)

	await _abrir_configuracoes()
	assert_int(_abertos).is_equal(1).override_failure_message(
		"FR-001: ui_accept na linha Configurações não emitiu open_settings"
	)
	assert_int(_emitidos_iniciar).is_zero().override_failure_message(
		"FR-001: ui_accept em Configurações emitiu start_race junto"
	)
	assert_bool(ui._painel_configuracoes.visible).is_true().override_failure_message(
		"RF-002: o painel de configurações não ficou visível"
	)


## 2 — Estado inicial do painel vindo do PreferencesManager do setup
## (contract §3) e destaque da navegação em 3 linhas (wrapi + _marcar_opcoes).
func test_02_estado_inicial_e_navegacao() -> void:
	assert_bool(ui._painel_configuracoes.visible).is_false().override_failure_message(
		"RF-002: o painel não pode nascer visível"
	)
	await _abrir_configuracoes()

	var texto_audio_padrao: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("audio_label", "")),
		String(GameConfig.ui_strings.get("audio_on", "")),
	]
	assert_str(ui._opcoes_config[0].text).is_equal(texto_audio_padrao)\
		.override_failure_message(
			"FR-002: linha de áudio inicial errada — veio '%s'" % ui._opcoes_config[0].text
		)
	var texto_res_padrao: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("resolution_label", "")),
		String(GameConfig.ui_strings.get("resolution_640", "")),
	]
	assert_str(ui._opcoes_config[1].text).is_equal(texto_res_padrao)\
		.override_failure_message(
			"FR-004: linha de resolução inicial errada — veio '%s'"
				% ui._opcoes_config[1].text
		)
	assert_int(ui._opcao_config).is_zero().override_failure_message(
		"RF-002: ao abrir, a seleção deve começar na linha Áudio"
	)

	await _pressionar("ui_down")
	assert_int(ui._opcao_config).is_equal(1).override_failure_message(
		"RF-002: ui_down no painel não avançou para a linha Resolução"
	)
	await _pressionar("ui_down")
	assert_int(ui._opcao_config).is_equal(2)
	await _pressionar("ui_down")
	assert_int(ui._opcao_config).is_zero().override_failure_message(
		"RF-002: navegação do painel não envolveu de 2 para 0 (wrapi 3 linhas)"
	)


## 3 — Alternar áudio emite settings_audio_alterado com o valor esperado e
## atualiza o rótulo (contract §3 linha 0 — ui_left/ui_right/ui_accept).
func test_03_alterna_audio_emite_e_atualiza() -> void:
	await _abrir_configuracoes()

	await _pressionar("ui_right")
	assert_array(_audio_emittido).is_equal([false]).override_failure_message(
		"FR-002: ui_right na linha Áudio não emitiu settings_audio_alterado(false)"
	)
	var texto_desligado: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("audio_label", "")),
		String(GameConfig.ui_strings.get("audio_off", "")),
	]
	assert_str(ui._opcoes_config[0].text).is_equal(texto_desligado)\
		.override_failure_message("FR-002: rótulo do áudio não refletiu a troca")

	await _pressionar("ui_accept")
	assert_array(_audio_emittido).is_equal([false, true]).override_failure_message(
		"FR-002: ui_accept na linha Áudio não emitiu settings_audio_alterado(true)"
	)

	await _pressionar("ui_left")
	assert_array(_audio_emittido).is_equal([false, true, false]).\
		override_failure_message("FR-002: ui_left na linha Áudio não alternou")


## 4 — Alternar resolução percorre GameConfig.preferencias_resolucoes com
## wrap e emite o valor novo (contract §3 linha 1).
func test_04_alterna_resolucao_com_wrap() -> void:
	await _abrir_configuracoes()
	ui._opcao_config = 1

	await _pressionar("ui_right")
	var esperada_1024 := Vector2i(1024, 768)
	assert_array(_resolucao_emittida).is_equal([esperada_1024])\
		.override_failure_message(
			"FR-004: ui_right na linha Resolução não emitiu 1024x768"
		)
	var texto_1024: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("resolution_label", "")),
		String(GameConfig.ui_strings.get("resolution_1024", "")),
	]
	assert_str(ui._opcoes_config[1].text).is_equal(texto_1024)\
		.override_failure_message("FR-004: rótulo da resolução não refletiu a troca")

	await _pressionar("ui_right")
	var esperada_640 := Vector2i(640, 480)
	assert_array(_resolucao_emittida).is_equal([esperada_1024, esperada_640])\
		.override_failure_message("FR-004: a resolução não envolveu para o início")


## 5 — Fechar pela linha "Voltar ao menu" (ui_accept) emite close_settings e
## devolve o menu principal visível (contract §3 linha 2).
func test_05_fechar_pela_linha_voltar() -> void:
	await _abrir_configuracoes()
	ui._opcao_config = 2
	await _pressionar("ui_accept")

	assert_int(_fechados).is_equal(1).override_failure_message(
		"RF-002: 'Voltar ao menu' não emitiu close_settings"
	)
	assert_bool(ui._painel_configuracoes.visible).is_false().override_failure_message(
		"RF-002: o painel continuou visível após fechar"
	)
	assert_bool(ui._painel_menu.visible).is_true().override_failure_message(
		"RF-002: o menu principal não voltou a ficar visível"
	)
	assert_int(_emitidos_iniciar).is_zero().override_failure_message(
		"fechar o painel emitiu start_race junto"
	)


## 6 — ui_cancel fecha de qualquer linha (contract §3 linha 2 / R9).
func test_06_ui_cancel_fecha() -> void:
	await _abrir_configuracoes()
	await _pressionar("ui_cancel")
	assert_int(_fechados).is_equal(1).override_failure_message(
		"RF-002: ui_cancel não fechou o painel com close_settings"
	)
	assert_bool(ui._painel_configuracoes.visible).is_false()

	# Reabre e cancela já na linha do áudio — mesma resposta.
	await _abrir_configuracoes()
	await _pressionar("ui_cancel")
	assert_int(_fechados).is_equal(2)
	assert_array(_audio_emittido).is_empty().override_failure_message(
		"ui_cancel na linha Áudio alternou o áudio junto (deveria só fechar)"
	)


## 7 — Após fechar, o menu principal segue navegável e o ui_accept na linha
## 3 emite start_race (a 4ª linha não quebra o fluxo legado).
func test_07_menu_utilizavel_apos_fechar() -> void:
	await _abrir_configuracoes()
	await _pressionar("ui_cancel")

	ui._opcao_menu = 3
	await _pressionar("ui_accept")
	assert_int(_emitidos_iniciar).is_equal(1).override_failure_message(
		"FR-001: 'Iniciar corrida' na linha 3 não emitiu start_race"
	)


## 8 — setup SEM preferências (chamada legada de 2 argumentos, R9) ⇒ o
## painel usa os defaults do GameConfig.
func test_08_setup_sem_preferencias_usa_defaults() -> void:
	var ui2 := UIManager.new()
	add_child(ui2)
	ui2.setup(track, GameState)
	ui2.set_process(false)
	ui2._opcao_menu = 2
	Input.action_press("ui_accept")
	ui2._process(0.0)
	Input.action_release("ui_accept")
	await get_tree().process_frame

	var texto_audio_padrao: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("audio_label", "")),
		String(GameConfig.ui_strings.get("audio_on", "")),
	]
	assert_str(ui2._opcoes_config[0].text).is_equal(texto_audio_padrao)\
		.override_failure_message("R9: setup de 2 argumentos não usou os defaults")
	ui2.queue_free()


## 9 — setup COM preferências reflete o estado do domínio (áudio desligado +
## 1024×768 carimbados no objeto antes do setup — contrato §3).
func test_09_setup_com_preferencias_reflete_o_dominio() -> void:
	var ui3 := UIManager.new()
	add_child(ui3)
	var pref := PreferencesManager.new("user://_teste_settings_menu_ui3.json")
	pref.audio_ativo = false
	pref.resolucao = Vector2i(1024, 768)
	ui3.setup(track, GameState, pref)
	ui3.set_process(false)
	ui3._opcao_menu = 2
	Input.action_press("ui_accept")
	ui3._process(0.0)
	Input.action_release("ui_accept")
	await get_tree().process_frame

	var texto_audio: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("audio_label", "")),
		String(GameConfig.ui_strings.get("audio_off", "")),
	]
	assert_str(ui3._opcoes_config[0].text).is_equal(texto_audio)\
		.override_failure_message("FR-002: o painel não refletiu audio_ativo=false")
	var texto_res: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("resolution_label", "")),
		String(GameConfig.ui_strings.get("resolution_1024", "")),
	]
	assert_str(ui3._opcoes_config[1].text).is_equal(texto_res)\
		.override_failure_message("FR-004: o painel não refletiu 1024x768")

	ui3.queue_free()
	pref = null


## 10 — SPEC-012 / T009 (US2): a linha de resolução reflete a preferência
## CARREGADA do arquivo; a alternância emite SOMENTE valores de
## `GameConfig.preferencias_resolucoes`; trocar resolução não emite nenhum
## sinal de corrida (start_race/select_next_mode/select_next_vehicle).
func test_10_resolucao_carregada_isolamento_de_sinais() -> void:
	# Preferência persistida em disco e recarregada — o painel reflete o
	# arquivo, não o default.
	_pref.resolucao = Vector2i(1024, 768)
	assert_bool(_pref.salvar()).is_true().override_failure_message(
		"preparação: falhou ao gravar a preferência de teste"
	)
	var recarregada := PreferencesManager.new("user://_teste_settings_menu.json")
	recarregada.carregar()
	assert_that(recarregada.resolucao).is_equal(Vector2i(1024, 768))\
		.override_failure_message("preparação: carregar() não restituiu 1024x768")

	var ui4 := UIManager.new()
	add_child(ui4)
	ui4.setup(track, GameState, recarregada)
	ui4.set_process(false)
	ui4._opcao_menu = 2
	Input.action_press("ui_accept")
	ui4._process(0.0)
	Input.action_release("ui_accept")
	await get_tree().process_frame

	var texto_1024: String = "%s: %s" % [
		String(GameConfig.ui_strings.get("resolution_label", "")),
		String(GameConfig.ui_strings.get("resolution_1024", "")),
	]
	assert_str(ui4._opcoes_config[1].text).is_equal(texto_1024)\
		.override_failure_message(
			"FR-004: a linha de resolução não refletiu a preferência carregada"
		)

	# Sinais de corrida/estado do menu, captados durante as alternâncias.
	var emitidos_iniciar: int = 0
	var emitidos_modo: int = 0
	var emitidos_veiculo: int = 0
	var emitidos_res: Array = []
	ui4.start_race.connect(func(): emitidos_iniciar += 1)
	ui4.select_next_mode.connect(func(): emitidos_modo += 1)
	ui4.select_next_vehicle.connect(func(): emitidos_veiculo += 1)
	ui4.settings_resolucao_alterada.connect(
		func(res: Vector2i): emitidos_res.append(res)
	)

	ui4._opcao_config = 1
	for i in 3:
		Input.action_press("ui_right")
		ui4._process(0.0)
		Input.action_release("ui_right")
		await get_tree().process_frame

	assert_int(emitidos_res.size()).is_greater_equal(2).override_failure_message(
		"FR-004: alternar a linha Resolução não emitiu settings_resolucao_alterada"
	)
	for res in emitidos_res:
		assert_bool(GameConfig.preferencias_resolucoes.has(res)).is_true()\
			.override_failure_message(
				"FR-004: emitida resolução fora do conjunto válido — %s" % str(res)
			)
	assert_int(emitidos_iniciar + emitidos_modo + emitidos_veiculo).is_zero()\
		.override_failure_message(
			"FR-004: trocar resolução emitiu sinal de corrida junto"
		)

	ui4.queue_free()
	recarregada = null


## 11 — T022 / contract §3 (FR-019, SC-005/SC-007): o fluxo completo com um
## MenuDemo real — abrir Configurações pausa a demonstração, fechar retoma, e
## a largada com o painel aberto a encerra SEM resíduos (o fecho forçado da UI
## emite close_settings, cujo retomar é no-op porque o estado já é PARADA).
func test_11_demo_pausa_retoma_e_encerra_no_fluxo() -> void:
	var demo := MenuDemo.new()
	add_child(demo)
	demo.iniciar()
	demo.set_process(false)
	ui.open_settings.connect(func(): demo.pausar())
	ui.close_settings.connect(func(): demo.retomar())

	# Abrir ⇒ pausado.
	await _abrir_configuracoes()
	assert_int(_abertos).is_equal(1).override_failure_message(
		"preparação: open_settings não emitido na linha 2"
	)
	assert_bool(demo.esta_ativo()).is_false().override_failure_message(
		"FR-019: abrir Configurações não pausou a demonstração"
	)

	# Fechar (ui_cancel) ⇒ retomado.
	await _pressionar("ui_cancel")
	assert_bool(ui._painel_configuracoes.visible).is_false()\
		.override_failure_message("preparação: ui_cancel não fechou o painel")
	assert_bool(demo.esta_ativo()).is_true().override_failure_message(
		"FR-019: fechar Configurações não retomou a demonstração"
	)

	# Largada com o painel aberto ⇒ demo encerrada, painel fechado, sem
	# resíduo de retomada (a ordem reproduz a do app: encerrar() do manager
	# no _show_ready antes do fecho forçado da UI no state_changed).
	await _abrir_configuracoes()
	assert_bool(demo.esta_ativo()).is_false().override_failure_message(
		"preparação: abrir a 2ª vez não pausou a demo"
	)
	demo.encerrar()
	GameState.start_game()

	assert_bool(demo.esta_ativo()).is_false().override_failure_message(
		"SC-005: close_settings ressuscitou a demo depois do encerrar() da largada"
	)
	assert_bool(ui._painel_configuracoes.visible).is_false()\
		.override_failure_message("SC-005: painel de configurações ficou aberto na largada")
	assert_int(_fechados).is_equal(2).override_failure_message(
		"SC-005: o fecho forçado da UI não emitiu close_settings"
	)

	demo.queue_free()
