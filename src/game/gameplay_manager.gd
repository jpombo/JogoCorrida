class_name GameplayManager
extends Node2D

## Gerenciador de cena de gameplay — integra GameState com a cena e orquestra
## os sistemas da corrida (SPEC-008: progressão, estados, combustível,
## galões; SPEC-009: dificuldade por modo e progressão infinita de
## ambientes). Componentes próprios por sistema (constitution §III); a ordem
## canônica de atualização por quadro está no research R9 e no contrato
## `game_state_transitions.md` (FR-017).

## Referências de cena (TrackLayer/ItemsLayer/UiLayer são aditivos do SPEC-008;
## `get_node_or_null` mantém testes sem a camada funcionando)
@onready var road = $Road
@onready var player_vehicle = $PlayerVehicle
@onready var background_layer = $BackgroundLayer
@onready var decoration_layer = $DecorationLayer
@onready var traffic_layer = $TrafficLayer
@onready var fuel_hud = $FuelHudLayer/FuelHudRoot
@onready var track_layer = get_node_or_null("TrackLayer")
@onready var items_layer = get_node_or_null("ItemsLayer")
@onready var ui_root = get_node_or_null("UiLayer/UIManagerRoot")

## GameState (autoload) — único dono das transições (FR-001)
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

## Progressão da corrida (SPEC-008, FR-005…FR-008): componente próprio;
## integrada pela velocidade de avanço, independente da rolagem (FR-007).
var track_manager: TrackManager = TrackManager.new()

## Configuração efetiva de dificuldade (SPEC-009, R8): dono do modo vigente
## e dos fatores por modo; injetado por referência nos sistemas no `_ready`
## e reafirmado a cada largada (o fator de ciclo muda entre corridas, FR-006).
var dificuldade: DifficultyManager = DifficultyManager.new()

## Progresso da sessão (SPEC-009, FR-019/FR-022/FR-023): posição na
## sequência de ambientes, vitórias do ciclo e ciclos concluídos. Dono do
## `environment_sequence` em runtime; não é persistente (fechar o jogo zera).
var progresso: RaceProgression = RaceProgression.new()

## Áudio da corrida (SPEC-010, FR-006): dono único da reprodução dos 3
## efeitos (AUD-001/002/003). Criado e configurado em `_ready` (contracts/
## audio_integration.md §1); nulo nos testes sintéticos que não rodam
## `_ready` — guards `if audio_manager:` em todo wiring (SC-009).
var audio_manager: AudioManager = null

## Seleção de veículo da sessão (SPEC-008, AS2/FR-002): padrão "azul";
## só troca o sprite — nunca atributos (SC-001/SC-014).
var _veiculo_selecionado: String = "azul"

## Contagem de 1 s do READY → PLAYING (guarda contra timers duplicados).
var _contagem_ready: bool = false

## Quadro em que o estado entrou em PLAYING (guarda do ESC — ver
## `_processar_playing`).
var _frame_play: int = -1

## Emitido 1× quando a corrida termina em vitória ou em derrota (SC-005).
signal race_won
signal race_lost

func _ready() -> void:
	# Conectar signals do GameState
	game_state.state_changed.connect(_on_state_changed)

	# SPEC-010 / FR-006: criação e configuração do áudio ANTES das conexões
	# de trânsito e de colisão (ordem de contracts/audio_integration.md §1).
	# A pool de motor deriva de traffic_max_vehicles + 1 (R5 — fonte única
	# da densidade; jogador incluído).
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	audio_manager.configurar({
		"colisao_path": GameConfig.audio_colisao_path,
		"caminhao_path": GameConfig.audio_caminhao_path,
		"carro_path": GameConfig.audio_carro_path,
		"vozes_colisao": GameConfig.audio_vozes_colisao,
		"vozes_motor": GameConfig.traffic_max_vehicles + 1,
		"volume_motor": GameConfig.audio_volume_motor,
		"volume_colisao": GameConfig.audio_volume_colisao,
		"categoria_caminhao": GameConfig.audio_categoria_caminhao,
	})

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
		# SPEC-010 / FR-002, R5: o som de motor acompanha o ciclo de vida
		# completo do veículo (nascimento e reciclagem).
		traffic_layer.vehicle_spawned.connect(
			func(v): audio_manager.ao_veiculo_surgir(v)
		)
		traffic_layer.vehicle_recycled.connect(
			func(v): audio_manager.ao_veiculo_sair(v)
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

	# SPEC-010 / FR-001 (Clarification Q1): AUD-001 em toda colisão
	# veicular relevante — jogador×NPC e NPC×NPC — 1 reprodução por evento,
	# payload ignorado, sem deduplicação própria (os sistemas SPEC-005/006
	# já emitem 1 evento por encontro).
	collision_system.collision_occurred.connect(
		func(_d): audio_manager.tocar_colisao()
	)
	npc_collision_system.npc_collision_occurred.connect(
		func(_d): audio_manager.tocar_colisao()
	)

	# SPEC-007 / T016: o HUD observa desde a origem; `setup` idempotente (H4).
	# Nulo apenas se a cena não tiver a camada (testes sem a árvore).
	if fuel_hud:
		fuel_hud.setup(fuel_system)

	# SPEC-008: coleta de galão restaura via autoridade única do FuelSystem
	# (R4/FR-033); UIManager observa e emite comandos (R12). Ambos idempotentes.
	if items_layer:
		items_layer.setup()
		items_layer.fuel_can_collected.connect(fuel_system.restaurar)
	if ui_root:
		ui_root.setup(track_manager, game_state)
		ui_root.start_race.connect(_on_start_race)
		ui_root.select_next_vehicle.connect(_on_select_next_vehicle)
		ui_root.select_next_mode.connect(_on_select_next_mode)
		ui_root.continue_race.connect(_on_continue_race)
		ui_root.continue_next_phase.connect(_on_continue_next_phase)
		ui_root.restart_race.connect(_on_restart_race)
		ui_root.go_to_menu.connect(_on_go_to_menu)

	# SPEC-009: modo padrão da sessão e fatores injetados nos sistemas
	# (contrato difficulty_manager_api.md §2). Os sistemas sem injeção
	# permanecem em 1,0 — os testes legados não passam por aqui (R12).
	dificuldade.definir_modo(String(GameConfig.difficulty_default_mode))
	_aplicar_fatores_por_corrida()
	if ui_root:
		ui_root.atualizar_modo(_rotulo_modo())

	# Iniciar no MENU
	game_state.reset()
	_show_menu()


## Injeta a configuração efetiva nos sistemas (SPEC-009, contracts/
## difficulty_manager_api.md §2): referência do DifficultyManager no
## trânsito e nos galões, fator de velocidade no controller do jogador e no
## consumo, e fator de penalidade no FuelSystem. Uma vez no `_ready` e
## refresh por corrida (`_on_start_race`) — nada lê modo em PLAYING (FR-006).
## Nulos são ignorados: testes que montam o manager sintético mantêm os
## defaults 1,0 (R12 — regressão intacta).
func _aplicar_fatores_por_corrida() -> void:
	if dificuldade == null:
		return
	var fator_velocidade: float = dificuldade.fator_velocidade_total()
	if player_vehicle and player_vehicle.controller:
		player_vehicle.controller.fator_dificuldade = fator_velocidade
	if fuel_system:
		fuel_system.fator_velocidade = fator_velocidade
		fuel_system.fator_penalidade_colisao = dificuldade.fator_penalidade_colisao()
	if traffic_layer:
		traffic_layer.dificuldade = dificuldade
		traffic_layer.fator_dificuldade = fator_velocidade
	if items_layer:
		items_layer.dificuldade = dificuldade


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

func _process(delta: float) -> void:
	# FR-031 / T061: troca de ambiente em runtime (ex.: configuração ao vivo)
	# propaga fundo e biblioteca de decoração sem exigir alteração de código.
	if GameConfig.current_environment_id != _ambiente_propagado:
		_propagar_ambiente(GameConfig.current_environment_id)

	match game_state.current_state:
		game_state.State.READY:
			if not _contagem_ready and get_tree() != null:
				_contagem_ready = true
				_aguardar_inicio()
		game_state.State.PLAYING:
			_processar_playing(delta)
		# MENU/PAUSED/VICTORY/GAME_OVER: a UI comanda via sinais; nenhum
		# sistema avança (FR-004/FR-036, research R11).


## Contagem de 1 s do READY; `begin_playing` no fim (a virada READY →
## PLAYING dispara `_reset_corrida` — a largada limpa da corrida, R10).
func _aguardar_inicio() -> void:
	await get_tree().create_timer(1.0).timeout
	_contagem_ready = false
	if game_state.current_state == game_state.State.READY:
		game_state.begin_playing()


## Ramo PLAYING — ordem canônica de R9 (FR-017):
## 1. rolagem da estrada e do fundo; 2. decoração → trânsito → NPC×NPC →
## limites do jogador → colisão jogador×NPC; 3. galões; 4. combustível;
## 5. progressão e marcadores; 6. transições; 7. flag de aceleração (R5).
func _processar_playing(delta: float) -> void:
	# Guarda de quadro (par da guarda da UI em `_process_pausa`): o ESC só
	# pausa a partir do quadro seguinte à virada para PLAYING. Assim um
	# `ui_cancel` que só existia para retomar (retomada no mesmo quadro, se a
	# UI processasse antes do manager) não vira pausa imediata — o toggle
	# fica estável em QUALQUER ordem de processamento entre os dois nós.
	if Input.is_action_just_pressed("ui_cancel") \
			and Engine.get_process_frames() > _frame_play:
		game_state.pause_game()
		return

	# SPEC-010 / FR-003 (Clarification Q3, R11): gate por quadro do som do
	# jogador — só toca com acelerador pressionado E sem freio (condição
	# idêntica à fase de aceleração do VehicleController); NPCs são
	# contínuos (FR-002). Custo: 1 chamada + 2 checagens de input/quadro,
	# sem alocação — o AudioManager segue sem `_process`.
	if audio_manager:
		audio_manager.ao_aceleracao_jogador(
			Input.is_action_pressed("accelerate")
			and not Input.is_action_pressed("brake")
		)

	# 1. Rolagem da estrada e do fundo
	if player_vehicle and road:
		road.update_scroll_speed(player_vehicle.get_speed())
	if background_layer and road:
		background_layer.update_scroll(road.scroll_speed, delta)

	# 2. Decoração → trânsito → colisão NPC×NPC → limites → colisão do jogador
	if decoration_layer and road:
		decoration_layer.update(delta, road)
	if traffic_layer and road:
		traffic_layer.update(delta, road)
		npc_collision_system.update(
			delta,
			traffic_layer.active_vehicles_snapshot,
			Callable(road, "get_boundaries_for_player_y"),
			road.scroll_speed
		)
	if player_vehicle and road:
		var boundaries = road.get_boundaries_for_player_y(player_vehicle.position.y)
		player_vehicle.controller.update_boundaries(boundaries.left, boundaries.right)
	if player_vehicle and traffic_layer and road:
		collision_system.update(
			delta, player_vehicle, traffic_layer.active_vehicles_snapshot,
			Callable(road, "get_boundaries_for_player_y")
		)

	# 3. Galões: movimento, reciclagem, geração e coleta ANTES do consumo
	# (a restauração do quadro entra na conta do consumo — caso de borda 4).
	if items_layer and road:
		items_layer.update(
			delta,
			road,
			traffic_layer.active_vehicles_snapshot if traffic_layer else [],
			track_manager,
			player_vehicle
		)

	# 4. Combustível (consumo após a restauração do quadro)
	if fuel_system and player_vehicle:
		fuel_system.update(delta, player_vehicle.get_speed())

	# 5. Progressão e marcadores (mesma rolagem da estrada)
	if player_vehicle:
		track_manager.update(delta, player_vehicle.get_speed())
	if track_layer and road:
		track_layer.update(delta, road.scroll_speed)

	# 6. Transições: vitória (cruzamento + combustível > 0); senão GAME_OVER
	# se combustível zero e parado sem concluir (FR-013, FR-016).
	_avaliar_transicoes()

	# 7. Flag de bloqueio de aceleração derivada do valor PÓS-consumo (R5):
	# sem latch — a coleta desbloqueia no mesmo instante em que o valor sobe.
	if player_vehicle and player_vehicle.controller and fuel_system:
		player_vehicle.controller.aceleracao_bloqueada_por_combustivel = (
			fuel_system.get_atual() <= 0.0
		)


## Transição de vitória/derrota avaliada só no ramo PLAYING e uma vez por
## corrida (`track_manager.esta_concluido()` + o no-op de `change_state` no
## mesmo estado — SC-005/SC-007). A precedência do esgotamento sobre o
## cruzamento no mesmo quadro vem da ordem de R9: o consumo (passo 4) roda
## antes desta checagem (caso de borda 1).
func _avaliar_transicoes() -> void:
	if game_state.current_state != game_state.State.PLAYING:
		return
	if track_manager.esta_concluido():
		return
	var cruzou: bool = false
	if track_layer != null and player_vehicle != null:
		cruzou = track_layer.banda_completamente_cruzou(
			player_vehicle.position.y, GameConfig.player_hitbox_size.y
		)
	if cruzou and fuel_system.get_atual() > 0.0:
		track_manager.marcar_concluido()
		# FR-031/SC-011: a corrida terminou — 0 galões ativos permanecem
		# após qualquer encerramento (idempotente; largada/menu já limpam).
		if items_layer:
			items_layer.reset()
		# SPEC-009 / FR-019: o avanço de fase é registrado ANTES da vitória
		# — `_on_continue_next_phase` consome o estado já avançado
		# (environment_cycle.md §2).
		progresso.registra_vitoria()
		race_won.emit()
		game_state.victory()
		return
	if fuel_system.get_atual() <= 0.0 and player_vehicle != null \
			and player_vehicle.get_speed() <= 0.0:
		if items_layer:
			items_layer.reset()
		# SPEC-009 / FR-023: derrota recomeça por PLAINS com ciclos
		# preservados (mesmo ponto de transição, environment_cycle.md §2).
		progresso.zerar_ciclo_por_derrota()
		race_lost.emit()
		game_state.game_over()


## Reset completo e idempotente da corrida (SPEC-008, FR-003/FR-035, R10).
## Chamado na preparação do fluxo menu → READY (`_on_start_race`, T059), na
## virada READY → PLAYING e pelo reinício imediato (`_on_restart_race`,
## T022); `go_to_menu` NÃO o chama (usa o reset de encerramento embutido).
## Conexões de sinais NUNCA são refeitas aqui (SC-012).
func _reset_corrida() -> void:
	# Capacidade derivada da corrida (Clarificação de capacidade, R3) ANTES
	# do reset — alterar track_total_distance muda o tanque automaticamente.
	var estimado: float = (
		GameConfig.track_total_distance * GameConfig.fuel_consumption_per_distance
		+ GameConfig.fuel_safety_margin
	)
	fuel_system.definir_capacidade_derivada(estimado)
	fuel_system.reset()

	track_manager.setup(GameConfig.track_total_distance)
	track_manager.reset()

	if items_layer:
		items_layer.reset()

	if player_vehicle:
		player_vehicle.reset()

	if track_layer:
		track_layer.reset()
		if player_vehicle:
			track_layer.criar_marcadores(
				player_vehicle.position.y, GameConfig.track_total_distance
			)

	if road:
		road.reset()
	if traffic_layer:
		traffic_layer.reset()
	collision_system.reset()
	npc_collision_system.reset()
	if decoration_layer:
		decoration_layer.reset()


## Comandos da UI (R12): a UI emite, o manager decide, o GameState transiciona
## (FR-001/FR-005).
func _on_start_race() -> void:
	_preparar_proxima_corrida()
	game_state.start_game()


## "Continuar próxima fase" (SPEC-009, FR-020; environment_cycle.md §3):
## o avanço de ambiente/ciclo já foi registrado na vitória
## (`_avaliar_transicoes` → `progresso.registra_vitoria`); aqui só se
## consome — mesmo preparo do menu → READY (garantia 2: mesma corrida do
## zero, modo selecionado mantido). Sem "Tentar novamente" (R10).
func _on_continue_next_phase() -> void:
	_preparar_proxima_corrida()
	game_state.start_game()


## Preparo comum do menu → READY e da vitória → próxima fase (SPEC-009,
## environment_cycle.md §2–§3):
## 1. ambiente da próxima corrida (`GameConfig.current_environment_id` —
##    a propagação existente no `_process` troca fundo/decoração, R9);
## 2. fator de ciclo novo na configuração efetiva (só entre corridas,
##    FR-006);
## 3. sprite do jogador + reset SPEC-008 + injeção de fatores por corrida
##    (T059: apresentação já no READY — indicador/tanque na carga inicial).
func _preparar_proxima_corrida() -> void:
	GameConfig.current_environment_id = progresso.ambiente_atual()
	dificuldade.aplicar_fator_ciclo(progresso.fator_ciclo())
	_aplicar_sprite_selecionado()
	# Reset idempotente do reinício (R10/SC-012): a virada READY → PLAYING
	# re-executa; `reset()` não toca nos fatores, a injeção reafirma.
	_reset_corrida()
	_aplicar_fatores_por_corrida()


func _on_select_next_vehicle() -> void:
	_veiculo_selecionado = "vermelho" if _veiculo_selecionado == "azul" else "azul"
	_aplicar_sprite_selecionado()


## Cicla o modo no DifficultyManager e devolve o rótulo à UI (SPEC-009,
## FR-016, R10): estado do modo vive no manager, a UI só exibe (contracts/
## ui_commands.md §1). Troca de modo só vale na PRÓXIMA largada (FR-006).
func _on_select_next_mode() -> void:
	if dificuldade == null:
		return
	dificuldade.ciclar_modo()
	if ui_root:
		ui_root.atualizar_modo(_rotulo_modo())


## Rótulo pt-BR do modo vigente, 100% de GameConfig.ui_strings (§VI).
func _rotulo_modo() -> String:
	if dificuldade == null:
		return ""
	return String(GameConfig.ui_strings.get("mode_" + dificuldade.get_modo(), ""))


func _aplicar_sprite_selecionado() -> void:
	if player_vehicle == null:
		return
	var caminho: String = (
		GameConfig.alt_sprite_path if _veiculo_selecionado == "vermelho"
		else GameConfig.default_sprite_path
	)
	player_vehicle.change_sprite(caminho)


func _on_continue_race() -> void:
	game_state.resume_game()


func _on_restart_race() -> void:
	# Reinício imediato (T022) + READY: a virada READY → PLAYING re-executa o
	# reset — idempotente (R10/SC-012), a corrida nasce limpa de qualquer
	# estado, inclusive de VICTORY/GAME_OVER.
	_reset_corrida()
	# SPEC-009 / SC-010: o reinício reaplica a configuração efetiva —
	# fatores vigentes do modo/ciclo reafirmados em 100% dos casos, mesmo
	# se algo externo tiver tocado nos campos injetados.
	_aplicar_fatores_por_corrida()
	game_state.start_game()


func _on_go_to_menu() -> void:
	# "Voltar ao menu": mesmos resets do encerramento + esconder mundo;
	# nenhum sistema continua avançando em segundo plano (FR-036, R10/R11).
	if road:
		road.reset()
	if track_layer:
		track_layer.reset()
	if items_layer:
		items_layer.reset()
	if player_vehicle:
		player_vehicle.reset()
	if traffic_layer:
		traffic_layer.reset()
	collision_system.reset()
	npc_collision_system.reset()
	if decoration_layer:
		decoration_layer.reset()
	game_state.reset()


func _on_state_changed(new_state: int, old_state: int) -> void:
	# SPEC-007 / FR-002, SC-001 + SPEC-008 / FR-003: o reset COMPLETO da
	# corrida (tanque derivado, progressão, marcadores, galões, trânsito,
	# colisões, decoração, veículo, estrada) é idempotente e já roda na
	# preparação (menu/restart → READY, T059/T022); aqui a virada
	# READY → PLAYING o re-executa como normalização final — uma vez por
	# partida; PAUSED → PLAYING preserva o saldo (research R4/R10).
	# Depende só dos campos dos sistemas — testável sem a árvore de cena.
	if old_state == game_state.State.READY and new_state == game_state.State.PLAYING:
		_reset_corrida()

	match new_state:
		game_state.State.MENU:
			_show_menu()
		game_state.State.READY:
			_show_ready()
		game_state.State.PLAYING:
			_show_playing()
		game_state.State.PAUSED:
			_show_paused()
		game_state.State.VICTORY:
			_show_victory()
		game_state.State.GAME_OVER:
			_show_game_over()

	# SPEC-010 / FR-006: encaminha POR ÚLTIMO — depois do reset e da
	# exibição (contracts/audio_integration.md §3). O encaminhamento é
	# síncrono por transição: em viradas no mesmo quadro, a última vence.
	if audio_manager:
		audio_manager.ao_alterar_estado(new_state, old_state)

func _show_menu() -> void:
	# T060 / US1 AS1 + FR-036: nada processa input em segundo plano no menu —
	# congela o jogador como já fazem pausa/fim. Sem isto o VehicleController
	# seguia mutando velocidade/posição invisível (e o carro se movia durante
	# o READY após acelerar no menu). _show_playing religa (mesmo caminho do
	# pós-vitória/game over, que chega aqui já congelado).
	if player_vehicle:
		player_vehicle.set_process(false)
		player_vehicle.visible = false
	if road:
		road.visible = false
	if track_layer:
		track_layer.visible = false
	if items_layer:
		items_layer.visible = false

func _show_ready() -> void:
	if road:
		road.visible = true
	if player_vehicle:
		player_vehicle.visible = true
	if track_layer:
		track_layer.visible = true
		# A banda de INÍCIO (e a de CHEGADA) nasce JÁ no READY — antes o
		# jogador só via o quadriculado após o timer de 1 s, quando a virada
		# PLAYING recriava os marcadores no reset da largada.
		if player_vehicle:
			track_layer.reset()
			track_layer.criar_marcadores(
				player_vehicle.position.y, GameConfig.track_total_distance
			)
	if items_layer:
		items_layer.visible = true

func _show_playing() -> void:
	# Marca o quadro da entrada para a guarda do ESC em `_processar_playing`.
	_frame_play = Engine.get_process_frames()
	if player_vehicle:
		player_vehicle.set_process(true)

func _show_paused() -> void:
	if player_vehicle:
		player_vehicle.set_process(false)
	# FR-004 / R11: a rolagem é zerada na pausa — sem isso o Road._process
	# reaplica a última scroll_speed e a estrada continuaria rolando.
	if road:
		road.update_scroll_speed(0.0)

func _show_victory() -> void:
	if player_vehicle:
		player_vehicle.set_process(false)
	if road:
		road.update_scroll_speed(0.0)

func _show_game_over() -> void:
	if player_vehicle:
		player_vehicle.set_process(false)
	if road:
		road.update_scroll_speed(0.0)
