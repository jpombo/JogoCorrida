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
var _rotulo_iniciar: Label = null
var _destaque_menu: ColorRect = null
var _opcoes_pausa: Array[Label] = []
var _opcoes_vitoria: Array[Label] = []
var _opcoes_gameover: Array[Label] = []
var _rotulo_distancia: Label = null
var _barra_fundo: ColorRect = null
var _barra: ColorRect = null

var _opcao_pausa: int = 0
var _opcao_vitoria: int = 0
var _opcao_gameover: int = 0
var _opcao_menu: int = 0
var _veiculo_indice: int = 0

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
func setup(p_track: TrackManager, p_state: Node) -> void:
	track_manager = p_track
	game_state = p_state
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
			_process_menu()
		game_state.State.PAUSED:
			_process_pausa()
		game_state.State.VICTORY:
			_process_fim_vitoria()
		game_state.State.GAME_OVER:
			_process_fim_gameover()


## Menu de 3 linhas (SPEC-009, FR-016, contracts/ui_commands.md §1):
## 0 = seleção de veículo, 1 = modo, 2 = iniciar corrida.
func _process_menu() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_opcao_menu = wrapi(_opcao_menu - 1, 0, 3)
		_posicionar_destaque_menu()
	if Input.is_action_just_pressed("ui_down"):
		_opcao_menu = wrapi(_opcao_menu + 1, 0, 3)
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
			_:
				start_race.emit()


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
	_painel_menu.visible = estado == game_state.State.MENU
	_painel_pausa.visible = estado == game_state.State.PAUSED
	_painel_vitoria.visible = estado == game_state.State.VICTORY
	_painel_gameover.visible = estado == game_state.State.GAME_OVER
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
## veículo com o nome; 1 = modo; 2 = iniciar corrida). Reaplica a posição a
## cada troca.
func _posicionar_destaque_menu() -> void:
	if _destaque_menu == null:
		return
	match _opcao_menu:
		0:
			_destaque_menu.position = Vector2(160.0, 164.0)
			_destaque_menu.size = Vector2(320.0, 66.0)
		1:
			_destaque_menu.position = Vector2(160.0, 244.0)
			_destaque_menu.size = Vector2(320.0, 32.0)
		_:
			_destaque_menu.position = Vector2(160.0, 284.0)
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

	_painel_menu = _criar_painel_fundo()
	_destaque_menu = ColorRect.new()
	_destaque_menu.color = Color(1.0, 1.0, 1.0, 0.18)
	_destaque_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_menu.add_child(_destaque_menu)
	_rotulo_titulo = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("menu_title", "")), 80.0
	)
	_rotulo_selecao = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("select_vehicle", "")), 170.0
	)
	_nome_veiculo = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("vehicle_blue", "")), 200.0
	)
	# Linha "Modo" (SPEC-009, FR-016): o rótulo inicial é o modo padrão da
	# config; `atualizar_modo` acompanha as trocas cicladas pelo manager.
	_rotulo_modo = _criar_rotulo_central(
		_painel_menu,
		"%s: %s" % [
			String(GameConfig.ui_strings.get("mode_label", "")),
			String(GameConfig.ui_strings.get("mode_normal", "")),
		],
		250.0
	)
	_rotulo_iniciar = _criar_rotulo_central(
		_painel_menu, String(GameConfig.ui_strings.get("start_race", "")), 290.0
	)

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
	_blocos_progresso.append(_criar_bloco_progresso(_painel_menu, 318.0))
	_blocos_progresso.append(_criar_bloco_progresso(_painel_vitoria, 236.0))
	_blocos_progresso.append(_criar_bloco_progresso(_painel_gameover, 236.0))

	_indicador = _construir_indicador()

	_painel_menu.visible = true
	_painel_pausa.visible = false
	_painel_vitoria.visible = false
	_painel_gameover.visible = false
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
