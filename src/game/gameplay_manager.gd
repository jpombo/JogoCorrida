extends Node2D

## Gerenciador de cena de gameplay — integra GameState com a cena

## Referências
@onready var road = $Road
@onready var player_vehicle = $PlayerVehicle

## GameState (autoload)
var game_state = GameState

func _ready() -> void:
	# Conectar signals do GameState
	game_state.state_changed.connect(_on_state_changed)
	
	# Iniciar no MENU
	game_state.reset()
	_show_menu()

func _process(_delta: float) -> void:
	# Transição de MENU para READY ao pressionar Enter/Espaço
	if game_state.current_state == game_state.State.MENU:
		if Input.is_action_just_pressed("ui_accept"):
			game_state.start_game()
	
	# Transição de READY para PLAYING após delay
	elif game_state.current_state == game_state.State.READY:
		await get_tree().create_timer(1.0).timeout
		game_state.begin_playing()
	
	# Pausa com Escape
	elif game_state.current_state == game_state.State.PLAYING:
		if Input.is_action_just_pressed("ui_cancel"):
			game_state.pause_game()
		
		# Atualizar scrolling da estrada com velocidade do veículo
		if player_vehicle:
			road.update_scroll_speed(player_vehicle.get_speed())
		
		# Atualizar limites baseado na posição Y do jogador
		# Isso permite transições precisas em segmentos de expansão/redução
		if player_vehicle and road:
			var boundaries = road.get_boundaries_for_player_y(player_vehicle.position.y)
			player_vehicle.controller.update_boundaries(boundaries.left, boundaries.right)
	
	# Retomar com Escape quando pausado
	elif game_state.current_state == game_state.State.PAUSED:
		if Input.is_action_just_pressed("ui_cancel"):
			game_state.resume_game()

func _on_state_changed(new_state: int, _old_state: int) -> void:
	match new_state:
		game_state.State.MENU:
			_show_menu()
		game_state.State.READY:
			_show_ready()
		game_state.State.PLAYING:
			_show_playing()
		game_state.State.PAUSED:
			_show_paused()

func _show_menu() -> void:
	road.visible = false
	player_vehicle.visible = false
	print("MENU — Pressione Enter para iniciar")

func _show_ready() -> void:
	road.visible = true
	player_vehicle.visible = true
	print("READY — Prepare-se...")

func _show_playing() -> void:
	player_vehicle.set_process(true)
	print("PLAYING — Jogo iniciado!")

func _show_paused() -> void:
	player_vehicle.set_process(false)
	print("PAUSED — Jogo pausado")
