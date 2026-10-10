extends Node2D

## Gerenciador de cena de gameplay — integra GameState com a cena

## Referências
@onready var road = $Road
@onready var player_vehicle = $PlayerVehicle
@onready var background_layer = $BackgroundLayer
@onready var decoration_layer = $DecorationLayer
@onready var traffic_layer = $TrafficLayer
@onready var fuel_hud = $FuelHudLayer/FuelHudRoot

## GameState (autoload)
var game_state = GameState

## Environment manager
var environment_manager: EnvironmentManager = EnvironmentManager.new()

## Último ambiente propagado aos sistemas (FR-031, T061).
## A troca de `GameConfig.current_environment_id` em runtime é detectada por
## comparação a cada quadro — um cheque de string por quadro, sem alloc e sem
## sinal novo em `EnvironmentManager` (D9: nada escreve em SPEC-003).
var _ambiente_propagado: String = ""

## Sistema de colisão (SPEC-005, FR-033): componente separado do trânsito;
## consome área ocupada, velocidade e limites vigentes, e emite o evento de
## colisão sem tocar nenhum outro sistema (FR-030).
var collision_system: CollisionSystem = CollisionSystem.new()

## Sistema de colisão NPC×NPC (SPEC-006, FR-036): também componente
## separado; consome os ativos do trânsito e os limites por altura, e só
## escreve em `position.x` dos envolvidos via drift (FR-017).
var npc_collision_system: NpcCollisionSystem = NpcCollisionSystem.new()

## Sistema de combustível (SPEC-007, FR-004/FR-018): componente próprio
## (constitution §III). Instanciado aqui para que `_on_state_changed` dependa
## apenas deste campo — sem referências de cena — e seja testável sem a árvore
## (SC-001, research R4).
var fuel_system: FuelSystem = FuelSystem.new()

func _ready() -> void:
	# Conectar signals do GameState
	game_state.state_changed.connect(_on_state_changed)

	# Configurar ambiente atual
	environment_manager.set_environment(GameConfig.current_environment_id)

	# SPEC-004: os dois sistemas recebem sua configuração de GameConfig e ficam
	# registrados com o ambiente vigente. Nenhum deles escreve em Road, em
	# PlayerVehicle ou em EnvironmentManager (FR-052, D9, I7).
	if traffic_layer:
		traffic_layer.setup(GameConfig.TRAFFIC_CATEGORIES)
		# SPEC-006 / FR-028: o nascimento passa a ser validado contra a
		# janela de atividade NPC×NPC. Nulo manteria o caminho legado do
		# SPEC-004 (o validador é consulta, não dependência).
		traffic_layer.validador = npc_collision_system
	if decoration_layer:
		decoration_layer.setup(GameConfig.DECORATION_LIBRARIES)

	# SPEC-006 / FR-033, R8: os eventos da dinâmica da área ativa disparam a
	# reavaliação (reconstrução do cache no próximo quadro; os vereditos são
	# recomputados sob demanda). Lambdas com a aridade exata de cada sinal —
	# `marcar_reavaliacao` não recebe argumentos. Os sinais são emitidos
	# durante as atualizações, ANTES do npc_collision_system no quadro, e o
	# rebuild acontece no mesmo quadro via `_revalidar_cache`.
	if traffic_layer:
		traffic_layer.vehicle_spawned.connect(
			func(_v): npc_collision_system.marcar_reavaliacao()
		)
		traffic_layer.vehicle_recycled.connect(
			func(_v): npc_collision_system.marcar_reavaliacao()
		)
	if road:
		road.segment_type_changed.connect(
			func(_tipo): npc_collision_system.marcar_reavaliacao()
		)
		road.boundary_changed.connect(
			func(_esq, _dir): npc_collision_system.marcar_reavaliacao()
		)

	_propagar_ambiente(GameConfig.current_environment_id)

	# SPEC-007 / FR-011, R12: a colisão do jogador (1 evento por contato
	# válido — SPEC-005) desconta combustível, com a penalidade lida no
	# momento do evento; sem deduplicação própria (FR-013).
	collision_system.collision_occurred.connect(fuel_system.on_player_collision)

	# SPEC-007 / T016: o HUD observa desde a origem; `setup` idempotente (H4).
	# Nulo apenas se a cena não tiver a camada (testes sem a árvore).
	if fuel_hud:
		fuel_hud.setup(fuel_system)

	# Iniciar no MENU
	game_state.reset()
	_show_menu()


## Propaga o ambiente vigente para fundo e decoração (FR-031, T061).
## Centraliza o que o `_ready` fazia na origem: resolve o ambiente no
## EnvironmentManager, troca a textura de fundo e avisa a DecorationLayer,
## que desativa a biblioteca anterior sem resíduo (SC-008, US6/AC1).
func _propagar_ambiente(id: String) -> void:
	environment_manager.set_environment(id)
	var env: EnvironmentData = environment_manager.get_current_environment()
	if env == null:
		return
	if background_layer:
		background_layer.set_texture(env.texture_path)
	if decoration_layer:
		decoration_layer.set_environment(env.id)
	# Registra o ID SOLICITADO: com id inválido o EnvironmentManager cai no
	# fallback "PLAINS", e gravar o resolvido faria a comparação por quadro
	# re-propagá-lo para sempre.
	_ambiente_propagado = id

func _process(_delta: float) -> void:
	# FR-031 / T061: troca de ambiente em runtime (ex.: configuração ao vivo)
	# propaga fundo e biblioteca de decoração sem exigir alteração de código.
	if GameConfig.current_environment_id != _ambiente_propagado:
		_propagar_ambiente(GameConfig.current_environment_id)

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

		# Atualizar scrolling do background
		if background_layer and road:
			background_layer.update_scroll(road.scroll_speed, _delta)

		# Hierarquia de atualização (FR-055, research.md R9).
		# Os passos 3 e 4 só podem usar o scroll_speed do quadro corrente, então
		# rodam depois de road._process, que é interno ao próprio Road.
		# Decoração antes do trânsito: a decoração reposicionada não pode ser confundida
		# com veículos na verificação visual de espaçamento (contrato §8).
		if decoration_layer and road:
			decoration_layer.update(_delta, road)

		if traffic_layer and road:
			traffic_layer.update(_delta, road)

		# SPEC-006: colisão NPC×NPC depois do trânsito (posições finais do
		# quadro) e ANTES do SPEC-005, para que um NPC já deslocado ocupe a
		# posição final quando o detector do jogador for avaliar — SC-015
		# observável no mesmo quadro do contato (T035, research R9).
		if traffic_layer and road:
			npc_collision_system.update(
				_delta,
				traffic_layer.active_vehicles_snapshot,
				Callable(road, "get_boundaries_for_player_y"),
				road.scroll_speed
			)

		# Atualizar limites baseado na posição Y do jogador
		# Isso permite transições precisas em segmentos de expansão/redução
		if player_vehicle and road:
			var boundaries = road.get_boundaries_for_player_y(player_vehicle.position.y)
			player_vehicle.controller.update_boundaries(boundaries.left, boundaries.right)

		# SPEC-005: colisão roda depois do trânsito (posições finais do quadro)
		# e depois dos limites do jogador; usa os limites vigentes por altura.
		if player_vehicle and traffic_layer and road:
			collision_system.update(
				_delta, player_vehicle, traffic_layer.active_vehicles_snapshot,
				Callable(road, "get_boundaries_for_player_y")
			)

		# SPEC-007 / FR-004, R12: consumo contínuo DEPOIS da colisão do quadro
		# (a penalidade já foi descontada em `on_player_collision`), apenas no
		# ramo PLAYING (FR-002, research R4).
		if fuel_system and player_vehicle:
			fuel_system.update(_delta, player_vehicle.get_speed())
	
	# Retomar com Escape quando pausado
	elif game_state.current_state == game_state.State.PAUSED:
		if Input.is_action_just_pressed("ui_cancel"):
			game_state.resume_game()

func _on_state_changed(new_state: int, old_state: int) -> void:
	# SPEC-007 / FR-002, SC-001: o tanque re-inicializa EXCLUSIVAMENTE na
	# virada READY → PLAYING (uma vez por partida); PAUSED → PLAYING preserva
	# o saldo (research R4). Depende só do campo `fuel_system` — testável sem
	# a árvore de cena (T004).
	if old_state == game_state.State.READY and new_state == game_state.State.PLAYING:
		fuel_system.reset()

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
