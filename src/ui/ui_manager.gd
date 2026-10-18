class_name UIManager
extends Control

## Telas da corrida (SPEC-008, FR-001/FR-034/FR-041, research R12): observador
## puro — nunca escreve em Track/Fuel/Player/GameState; os comandos saem por
## sinais consumidos pelo GameplayManager, que chama GameState/resets. Textos
## 100% vindos de GameConfig.ui_strings (§VI). Painéis construídos em código
## com Control/ColorRect/Label (mesma estética do FuelHud; escala inteira).

signal start_race
signal select_next_vehicle
signal select_next_mode
signal continue_race
signal restart_race
signal continue_next_phase
signal go_to_menu

# SPEC-012 (contracts/settings_menu_commands.md §1): a UI só exibe e emite —
# persistência/aplicação das preferências são do GameplayManager.
signal open_settings
signal close_settings
signal settings_audio_alterado(ativo: bool)
signal settings_resolucao_alterada(resolucao: Vector2i)

var track_manager: TrackManager = null
var game_state: Node = null

var _painel_menu: Control = null
var _painel_pausa: Control = null
var _painel_vitoria: Control = null
var _painel_gameover: Control = null
var _indicador: Control = null

var _rotulo_titulo: Label = null
var _rotulo_selecao: Label = null
var _nome_veiculo: Label = null
var _rotulo_modo: Label = null
var _rotulo_configuracoes: Label = null
var _rotulo_iniciar: Label = null
var _destaque_menu: ColorRect = null
var _opcoes_menu: Array[Label] = []
var _opcoes_pausa: Array[Label] = []
var _opcoes_vitoria: Array[Label] = []
var _opcoes_gameover: Array[Label] = []
var _rotulo_distancia: Label = null
var _barra_fundo: ColorRect = null
var _barra: ColorRect = null

# Painel de configurações (SPEC-012, RF-001/RF-002).
var _painel_configuracoes: Control = null
var _opcoes_config: Array[Label] = []

## Véu de legibilidade (SPEC-012, RF-010, contract settings_menu §5): ColorRect
## tela cheia, primeiro filho do root da UI — atrás dos textos, acima da
## demonstração de fundo; visível só nas telas do menu/configurações.
var _fundo_menu: ColorRect = null

var _opcao_pausa: int = 0
var _opcao_vitoria: int = 0
var _opcao_gameover: int = 0
var _opcao_menu: int = 0
var _opcao_config: int = 0
var _configuracoes_aberto: bool = false
var _veiculo_indice: int = 0

# Espelho exibido das preferências — somente leitura: os valores vêm do
# PreferencesManager no `setup` e as trocas saem por sinais; quem persiste e
# quem re-injeta é o GameplayManager (contracts settings §1 e
# preferences_manager_api §3).
var _audio_ativo: bool = GameConfig.preferencias_padrao_audio
var _resolucao: Vector2i = GameConfig.preferencias_resolucao_padrao

## Bloco de progressão (SPEC-011, FR-012/FR-023; contracts/
## ui_progress_display.md): um conjunto por painel (menu/vitória/game over),
## atualizado em conjunto por `atualizar_painel_progresso`.
var _blocos_progresso: Array[Dictionary] = []
var _texturas_trofeu: Dictionary = {}

## Quadro em que o estado entrou em PAUSED (guarda do ESC — ver _process_pausa).
var _frame_pausa: int = -1

var _configurado: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carregar_texturas_trofeu()
	_construir_paineis()


## Texturas dos ícones de troféu carregadas 1× (FR-013, research R11):
## arquivo ausente ⇒ modo fica sem ícone, sem erro de console (SC-012).
func _carregar_texturas_trofeu() -> void:
	for modo in GameConfig.trofeu_assets:
		var caminho: String = String(GameConfig.trofeu_assets[modo])
		if ResourceLoader.exists(caminho):
			var textura = load(caminho)
			if textura != null:
				_texturas_trofeu[modo] = textura


## Liga o observador aos modelos. Idempotente (H4): reconectar no mesmo par é
## no-op — o reset de corrida NUNCA reconecta (SC-012, research R10).
## SPEC-012 / contract §3: o 3º parâmetro é opcional para preservar as
## chamadas legadas de 2 argumentos (R9); sem preferências, o painel de
## configurações usa os defaults do GameConfig.
func setup(
	p_track: TrackManager,
	p_state: Node,
	p_preferencias: PreferencesManager = null
) -> void:
	track_manager = p_track
	game_state = p_state
	if p_preferencias != null:
		_audio_ativo = p_preferencias.audio_ativo
		_resolucao = p_preferencias.resolucao
	else:
		_audio_ativo = GameConfig.preferencias_padrao_audio
		_resolucao = GameConfig.preferencias_resolucao_padrao
	_atualizar_linhas_config()
	if track_manager != null and not track_manager.progress_changed.is_connected(_on_progress_changed):
		track_manager.progress_changed.connect(_on_progress_changed)
	if game_state != null and not game_state.state_changed.is_connected(_on_state_changed):
		game_state.state_changed.connect(_on_state_changed)
	_configurado = true
	_atualizar_nome_veiculo()
	_aplicar_estado()


## Navegação por teclado (ações já existentes do projeto). Em PAUSED,
## `ui_cancel` = Continuar (compatível com o atalho Escape — R12).
func _process(_delta: float) -> void:
	if not _configurado or game_state == null:
		return
	match game_state.current_state:
		game_state.State.MENU:
			# SPEC-012: o painel de configurações vive dentro do estado MENU —
			# aberto, ele consome a navegação no lugar do menu principal.
			if _configuracoes_aberto:
				_process_configuracoes()
			else:
				_process_menu()
		game_state.State.PAUSED:
			_process_pausa()
		game_state.State.VICTORY:
			_process_fim_vitoria()
		game_state.State.GAME_OVER:
			_process_fim_gameover()


## Menu de 4 linhas (SPEC-009 FR-016 + SPEC-012 FR-001, contract
## settings_menu §2): 0 = seleção de veículo, 1 = modo, 2 = configurações
## (abre o painel), 3 = iniciar corrida.
func _process_menu() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_opcao_menu = wrapi(_opcao_menu - 1, 0, 4)
		_posicionar_destaque_menu()
	if Input.is_action_just_pressed("ui_down"):
		_opcao_menu = wrapi(_opcao_menu + 1, 0, 4)
		_posicionar_destaque_menu()
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		_veiculo_indice = 1 - _veiculo_indice
		_atualizar_nome_veiculo()
		select_next_vehicle.emit()
	if Input.is_action_just_pressed("ui_accept"):
		match _opcao_menu:
			0:
				_veiculo_indice = 1 - _veiculo_indice
				_atualizar_nome_veiculo()
				select_next_vehicle.emit()
			1:
				select_next_mode.emit()
			2:
				_abrir_configuracoes()
			_:
				start_race.emit()


## Painel de configurações (SPEC-012, contract settings_menu §3): 3 linhas —
## 0 = áudio, 1 = resolução (ui_left/ui_right/ui_accept alternam), 2 =
## "Voltar ao menu" (ui_accept/ui_cancel fecham). O painel só exibe e emite.
func _process_configuracoes() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_opcao_config = wrapi(_opcao_config - 1, 0, 3)
		_marcar_opcoes(_opcoes_config, _opcao_config)
	if Input.is_action_just_pressed("ui_down"):
		_opcao_config = wrapi(_opcao_config + 1, 0, 3)
		_marcar_opcoes(_opcoes_config, _opcao_config)
	if Input.is_action_just_pressed("ui_cancel"):
		_fechar_configuracoes()
		return
	if Input.is_action_just_pressed("ui_accept"):
		match _opcao_config:
			0:
				_alternar_audio()
			1:
				_alternar_resolucao()
			_:
				_fechar_configuracoes()
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		match _opcao_config:
			0:
				_alternar_audio()
			1:
				_alternar_resolucao()


## Abre/fecha o painel: o menu principal sai de cena (sem duplo fundo) e os
## sinais orientam o GameplayManager a pausar/retomar a demonstração (RF-009).
func _abrir_configuracoes() -> void:
	_configuracoes_aberto = true
	_opcao_config = 0
	_marcar_opcoes(_opcoes_config, _opcao_config)
	_painel_menu.visible = false
	_painel_configuracoes.visible = true
	open_settings.emit()


func _fechar_configuracoes() -> void:
	_configuracoes_aberto = false
	_painel_configuracoes.visible = false
	_painel_menu.visible = true
	close_settings.emit()


func _alternar_audio() -> void:
	_audio_ativo = not _audio_ativo
	_atualizar_linhas_config()
	settings_audio_alterado.emit(_audio_ativo)


func _alternar_resolucao() -> void:
	var lista: Array[Vector2i] = GameConfig.preferencias_resolucoes
	var indice := lista.find(_resolucao)
	_resolucao = lista[wrapi(indice + 1, 0, lista.size())]
	_atualizar_linhas_config()
	settings_resolucao_alterada.emit(_resolucao)


## Reescreve as linhas de áudio/resolução a partir do espelho corrente
## (chamado no `setup` e após cada alternância).
func _atualizar_linhas_config() -> void:
	if _opcoes_config.size() >= 2:
		_opcoes_config[0].text = _texto_linha_audio()
		_opcoes_config[1].text = _texto_linha_resolucao()


func _texto_linha_audio() -> String:
	var chave := "audio_on" if _audio_ativo else "audio_off"
	return "%s: %s" % [
		String(GameConfig.ui_strings.get("audio_label", "")),
		String(GameConfig.ui_strings.get(chave, "")),
	]


func _texto_linha_resolucao() -> String:
	var rotulo := String(GameConfig.ui_strings.get("resolution_label", ""))
	# Específica para o conjunto válido do GameConfig (T026: sem resolução
	# literal no código da UI) — chave "resolution_<largura>".
	for res in GameConfig.preferencias_resolucoes:
		if _resolucao == res:
			return "%s: %s" % [
				rotulo,
				String(GameConfig.ui_strings.get("resolution_%d" % res.x, "")),
			]
	return "%s: %d \u00d7 %d" % [rotulo, _resolucao.x, _resolucao.y]


func _process_pausa() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_opcao_pausa = wrapi(_opcao_pausa - 1, 0, _opcoes_pausa.size())
		_marcar_opcoes(_opcoes_pausa, _opcao_pausa)
	if Input.is_action_just_pressed("ui_down"):
		_opcao_pausa = wrapi(_opcao_pausa + 1, 0, _opcoes_pausa.size())
		_marcar_opcoes(_opcoes_pausa, _opcao_pausa)
	# Guarda de quadro: o MESMO Escape que pausou continua "just pressed"
	# no quadro da virada PLAYING → PAUSED (o GameplayManager, que está acima
	# na árvore, já correu antes da UI neste quadro). Sem a guarda a pausa e a
	# retomada aconteciam juntas e o painel — e a opção "Voltar ao menu" —
	# nunca chegavam a ser desenhados. O ESC só retoma a partir do quadro
	# seguinte, independente da ordem de processamento entre os dois nós.
	if Input.is_action_just_pressed("ui_cancel") \
			and Engine.get_process_frames() > _frame_pausa:
		continue_race.emit()
		return
	if Input.is_action_just_pressed("ui_accept"):
		match _opcao_pausa:
			0:
				continue_race.emit()
			1:
				restart_race.emit()
			_:
				go_to_menu.emit()


## Vitória (SPEC-009, FR-020): exatamente 2 opções — Continuar próxima
## fase (0) e Voltar ao menu (1). "Tentar novamente" removido (R10).
func _process_fim_vitoria() -> void:
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
		_opcao_vitoria = wrapi(_opcao_vitoria + 1, 0, 2)
		_marcar_opcoes(_opcoes_vitoria, _opcao_vitoria)
	if Input.is_action_just_pressed("ui_accept"):
		if _opcao_vitoria == 0:
			continue_next_phase.emit()
		else:
			go_to_menu.emit()


## Fim de jogo (SPEC-009, FR-021): apenas "Voltar ao menu" — sem navegação
## e sem "Tentar novamente" (reinicio por derrota só via menu).
func _process_fim_gameover() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		go_to_menu.emit()


func _on_state_changed(_new_state: int, _old_state: int) -> void:
	_aplicar_estado()


func _aplicar_estado() -> void:
	if not _configurado or game_state == null:
		return
	var estado = game_state.current_state
	# SPEC-012: o painel só existe dentro do MENU — qualquer virada fecha-o
	# pelo caminho canônico (emite close_settings ⇒ a demo retoma).
	if _configuracoes_aberto:
		_fechar_configuracoes()
	_painel_menu.visible = estado == game_state.State.MENU
	_painel_pausa.visible = estado == game_state.State.PAUSED
	_painel_vitoria.visible = estado == game_state.State.VICTORY
	_painel_gameover.visible = estado == game_state.State.GAME_OVER
	# SPEC-012 / RF-010: o véu acompanha SÓ as telas de menu — inclui o
	# painel de configurações, que vive dentro do estado MENU.
	_fundo_menu.visible = estado == game_state.State.MENU
	_indicador.visible = estado != game_state.State.MENU
	if estado == game_state.State.MENU:
		_opcao_menu = 0
		_posicionar_destaque_menu()
	elif estado == game_state.State.PAUSED:
		# Marca o quadro da entrada para a guarda do ESC em _process_pausa.
		_frame_pausa = Engine.get_process_frames()
		_opcao_pausa = 0
		_marcar_opcoes(_opcoes_pausa, _opcao_pausa)
	elif estado == game_state.State.VICTORY:
		_opcao_vitoria = 0
		_marcar_opcoes(_opcoes_vitoria, _opcao_vitoria)
	elif estado == game_state.State.GAME_OVER:
		_opcao_gameover = 0
		_marcar_opcoes(_opcoes_gameover, _opcao_gameover)


## O indicador congela sozinho quando o TrackManager para de emitir (pausa e
## fim de corrida) — o UI nunca congela nada ativamente (R12).
func _on_progress_changed(percorrida: float, total: float, _percentual: float) -> void:
	_rotulo_distancia.text = String(GameConfig.ui_strings.get("distance_format", "")) \
		% [percorrida, total]
	if total > 0.0:
		_barra.scale.x = clampf(percorrida / total, 0.0, 1.0)
	else:
		_barra.scale.x = 0.0


func _atualizar_nome_veiculo() -> void:
	if _nome_veiculo == null:
		return
	var chave: String = "vehicle_red" if _veiculo_indice == 1 else "vehicle_blue"
	_nome_veiculo.text = String(GameConfig.ui_strings.get(chave, ""))


## Retângulo semitransparente atrás da opção ativa do menu (0 = seleção de
## veículo com o nome; 1 = modo; 2 = configurações; 3 = iniciar corrida).
## Reaplica a posição a cada troca. SPEC-012: 4 faixas com as posições
## mínimas para acomodar a nova linha (contract §2 — sem redesenho).
func _posicionar_destaque_menu() -> void:
	if _destaque_menu == null:
		return
	match _opcao_menu:
		0:
			_destaque_menu.position = Vector2(160.0, 144.0)
			_destaque_menu.size = Vector2(320.0, 66.0)
		1:
			_destaque_menu.position = Vector2(160.0, 218.0)
			_destaque_menu.size = Vector2(320.0, 32.0)
		2:
			_destaque_menu.position = Vector2(160.0, 254.0)
			_destaque_menu.size = Vector2(320.0, 32.0)
		_:
			_destaque_menu.position = Vector2(160.0, 290.0)
			_destaque_menu.size = Vector2(320.0, 32.0)


## Atualiza a linha "Modo" do menu com o rótulo recebido (FR-017, R10): a UI
## só exibe — o estado do modo vive no DifficultyManager e a sincronização
## é do GameplayManager (contracts/ui_commands.md §1/§5).
## SPEC-011 / SC-006: com o id do modo, o ícone de troféu acompanha a linha.
func atualizar_modo(rotulo: String, modo_id: String = "") -> void:
	if _rotulo_modo != null:
		_rotulo_modo.text = "%s: %s" % [
			String(GameConfig.ui_strings.get("mode_label", "")), rotulo
		]
	if modo_id != "":
		_aplicar_icone_trofeu(modo_id)


## Atualiza o bloco de progressão dos painéis de menu/vitória/Fim de Jogo a
## partir do snapshot do ProgressManager (SPEC-011, FR-012/FR-023;
## data-model §1.5). T041 / contract §5: sem snapshot (nulo ou vazio) é no-op
## real — nunca escreve defaults sobre painéis já exibidos.
func atualizar_painel_progresso(dados: Dictionary) -> void:
	if dados == null or dados.is_empty():
		return
	var d: Dictionary = dados
	var recorde: float = float(d.get("recorde", 0.0))
	var acumulada: float = float(d.get("acumulada", 0.0))
	var trofeus: int = int(d.get("trofeus", 0))
	var progresso_k: int = int(d.get("progresso_k", 0))
	var pontuacao: float = float(d.get("pontuacao", -1.0))
	var desbloqueado: bool = bool(d.get("desbloqueado", false))
	var texto_trofeus: String = String(GameConfig.ui_strings.get("trophy_format", "")) \
		% [trofeus, progresso_k]
	var texto_recorde: String = "%s: %.1f" % [
		String(GameConfig.ui_strings.get("record_label", "")), recorde
	]
	var texto_acumulada: String = "%s: %.1f" % [
		String(GameConfig.ui_strings.get("accumulated_label", "")), acumulada
	]
	var texto_pontuacao: String = String(GameConfig.ui_strings.get("victory_score", "")) \
		% pontuacao
	var texto_obstaculos: String = String(GameConfig.ui_strings.get(
		"obstacles_available" if desbloqueado else "obstacles_locked", ""
	))
	for bloco in _blocos_progresso:
		var rotulo: Label = bloco.get("trofeus")
		if rotulo != null:
			rotulo.text = texto_trofeus
		rotulo = bloco.get("recorde")
		if rotulo != null:
			rotulo.text = texto_recorde
		rotulo = bloco.get("acumulada")
		if rotulo != null:
			rotulo.text = texto_acumulada
		rotulo = bloco.get("pontuacao")
		if rotulo != null:
			rotulo.text = texto_pontuacao
			# FR-003/Q2-B: derrota/menu não têm pontuação de corrida.
			rotulo.visible = pontuacao > 0.0
		rotulo = bloco.get("obstaculos")
		if rotulo != null:
			rotulo.text = texto_obstaculos
	var modo: String = String(d.get("modo", ""))
	if modo != "":
		_aplicar_icone_trofeu(modo)


## Ícone 32×32 do modo (SC-006: desvio 0 px, asset por modo — FR-013).
func _aplicar_icone_trofeu(modo: String) -> void:
	var textura = _texturas_trofeu.get(modo, null)
	for bloco in _blocos_progresso:
		var icone: TextureRect = bloco.get("icone")
		if icone != null:
			icone.texture = textura


# ---------------------------------------------------------------------------
# Construção dos painéis (sem cena — Control/ColorRect/Label)
# ---------------------------------------------------------------------------

func _construir_paineis() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# SPEC-012 / RF-010 (contract §5): scrim PRIMEIRO filho do root — desenha
	# atrás de todos os painéis/textos e acima da demo de mundo, garantindo
	# leitura do título/opções sobre qualquer ambiente (SC-008). Alpha do
	# GameConfig (calibração quickstart §5).
	_fundo_menu = ColorRect.new()
	_fundo_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo_menu.color = Color(0.0, 0.0, 0.0, float(GameConfig.demo_ui_scrim_alpha))
	_fundo_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo_menu)

	_painel_menu = _criar_painel_fundo()
	_destaque_menu = ColorRect.new()
	_destaque_menu.color = Color(1.0, 1.0, 1.0, 0.18)
	_destaque_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_menu.add_child(_destaque_menu)
	_rotulo_titulo = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("menu_title", "")), 80.0
	)
	_rotulo_selecao = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("select_vehicle", "")), 150.0
	)
	_nome_veiculo = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("vehicle_blue", "")), 180.0
	)
	# Linha "Modo" (SPEC-009, FR-016): o rótulo inicial é o modo padrão da
	# config; `atualizar_modo` acompanha as trocas cicladas pelo manager.
	_rotulo_modo = _criar_rotulo_central(
		_painel_menu,
		"%s: %s" % [
			String(GameConfig.ui_strings.get("mode_label", "")),
			String(GameConfig.ui_strings.get("mode_normal", "")),
		],
		224.0
	)
	# Linha "Configurações" (SPEC-012, FR-001): índice 2 do menu de 4.
	_rotulo_configuracoes = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("settings", "")), 260.0
	)
	_rotulo_iniciar = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("start_race", "")), 296.0
	)
	_opcoes_menu = [
		_rotulo_selecao, _rotulo_modo, _rotulo_configuracoes, _rotulo_iniciar
	]

	# Painel de configurações (SPEC-012, RF-001, contract §3): 3 linhas —
	# áudio, resolução e "Voltar ao menu"; textos iniciais do espelho, que o
	# `setup` realinha com o PreferencesManager recebido.
	_painel_configuracoes = _criar_painel_fundo()
	_criar_rotulo_central(
		_painel_configuracoes,
		String(GameConfig.ui_strings.get("settings_title", "")),
		100.0
	)
	_opcoes_config = _criar_opcoes(_painel_configuracoes, [
		_texto_linha_audio(),
		_texto_linha_resolucao(),
		String(GameConfig.ui_strings.get("back_to_menu", "")),
	], 200.0)

	_painel_pausa = _criar_painel_fundo()
	_criar_rotulo_central(
		_painel_pausa, String(GameConfig.ui_strings.get("paused", "")), 100.0
	)
	_opcoes_pausa = _criar_opcoes(_painel_pausa, [
		String(GameConfig.ui_strings.get("continue_race", "")),
		String(GameConfig.ui_strings.get("restart_race", "")),
		String(GameConfig.ui_strings.get("back_to_menu", "")),
	], 170.0)

	_painel_vitoria = _criar_painel_fundo()
	_criar_rotulo_central(
		_painel_vitoria, String(GameConfig.ui_strings.get("victory", "")), 100.0
	)
	# SPEC-009 / FR-020: vitória oferece avanço de fase (novo) e saída para o
	# menu — "Tentar novamente" removido (contracts/ui_commands.md §4).
	_opcoes_vitoria = _criar_opcoes(_painel_vitoria, [
		String(GameConfig.ui_strings.get("continue_next_phase", "")),
		String(GameConfig.ui_strings.get("back_to_menu", "")),
	], 170.0)

	_painel_gameover = _criar_painel_fundo()
	_criar_rotulo_central(
		_painel_gameover, String(GameConfig.ui_strings.get("game_over", "")), 100.0
	)
	# SPEC-009 / FR-021: fim de jogo tem apenas "Voltar ao menu" — o
	# reinício por derrota é só via menu (Q1-A/Q2-B).
	_opcoes_gameover = _criar_opcoes(_painel_gameover, [
		String(GameConfig.ui_strings.get("back_to_menu", "")),
	], 170.0)

	# SPEC-011 / FR-012/FR-023: bloco de progressão nos 3 painéis — nada
	# novo em PLAYING (o bloco só vive em painéis de menu/encerramento).
	# SPEC-012: base do menu deslocada 318 → 326 para abrir espaço para a
	# 4ª linha do menu (labels até y=454 + 24 ≤ 480).
	_blocos_progresso.append(_criar_bloco_progresso(_painel_menu, 326.0))
	_blocos_progresso.append(_criar_bloco_progresso(_painel_vitoria, 236.0))
	_blocos_progresso.append(_criar_bloco_progresso(_painel_gameover, 236.0))

	_indicador = _construir_indicador()

	_painel_menu.visible = true
	_painel_pausa.visible = false
	_painel_vitoria.visible = false
	_painel_gameover.visible = false
	_painel_configuracoes.visible = false
	_fundo_menu.visible = true
	_indicador.visible = false
	_posicionar_destaque_menu()


func _construir_indicador() -> Control:
	var painel := Control.new()
	painel.name = "DistanceIndicator"
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel)

	_barra_fundo = ColorRect.new()
	_barra_fundo.position = Vector2(440.0, 10.0)
	_barra_fundo.size = Vector2(180.0, 14.0)
	_barra_fundo.color = Color(0.1, 0.1, 0.12, 0.85)
	_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(_barra_fundo)

	_barra = ColorRect.new()
	_barra.position = Vector2(442.0, 12.0)
	_barra.size = Vector2(176.0, 10.0)
	_barra.color = Color(0.18, 0.72, 0.31, 1.0)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(_barra)

	_rotulo_distancia = Label.new()
	_rotulo_distancia.position = Vector2(440.0, 28.0)
	_rotulo_distancia.add_theme_font_size_override("font_size", 11)
	_rotulo_distancia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(_rotulo_distancia)
	return painel


func _criar_painel_fundo() -> Control:
	var painel := Control.new()
	painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.0, 0.0, 0.0, 0.7)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(fundo)
	add_child(painel)
	return painel


func _criar_rotulo_central(painel: Control, texto: String, y: float) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.position = Vector2(0.0, y)
	rotulo.size = Vector2(640.0, 24.0)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 16)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(rotulo)
	return rotulo


func _criar_opcoes(painel: Control, textos: Array, y: float) -> Array[Label]:
	var resultado: Array[Label] = []
	for i in textos.size():
		var rotulo := _criar_rotulo_central(painel, textos[i], y + i * 30.0)
		resultado.append(rotulo)
	_marcar_opcoes(resultado, 0)
	return resultado


## Bloco de progressão (SPEC-011): ícone 32×32 + rótulos de troféus,
## recorde, acumulada, pontuação da corrida e obstáculos — texturas/textos
## chegam via `atualizar_painel_progresso` (contract ui_progress_display §2).
func _criar_bloco_progresso(painel: Control, y_base: float) -> Dictionary:
	var icone := TextureRect.new()
	icone.position = Vector2(304.0, y_base)
	icone.size = Vector2(32.0, 32.0)
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(icone)

	var trofeus := _criar_rotulo_central(painel, "", y_base + 40.0)
	var recorde := _criar_rotulo_central(painel, "", y_base + 62.0)
	var acumulada := _criar_rotulo_central(painel, "", y_base + 84.0)
	var pontuacao := _criar_rotulo_central(painel, "", y_base + 106.0)
	var obstaculos := _criar_rotulo_central(painel, "", y_base + 128.0)
	# Estado inicial coerente com snapshot vazio (SC-012: sem texto velho;
	# a pontuação da corrida só aparece com valor positivo).
	pontuacao.visible = false
	return {
		"icone": icone,
		"trofeus": trofeus,
		"recorde": recorde,
		"acumulada": acumulada,
		"pontuacao": pontuacao,
		"obstaculos": obstaculos,
	}


func _marcar_opcoes(opcoes: Array[Label], selecionada: int) -> void:
	for i in opcoes.size():
		opcoes[i].add_theme_color_override(
			"font_color", Color.YELLOW if i == selecionada else Color.WHITE
		)
