extends GdUnitTestSuite

## SPEC-011 / T009 (US1) — Fluxo de encerramento no orquestrador
## (SC-003/SC-011, research R7, contract progress_manager_api §3): vitória
## chama `processar_vitoria` UMA vez + `save.gravar` UMA vez, nessa ordem;
## derrota chama `processar_derrota` + gravar sem criar resultado; manager
## sintético sem `_ready` com campos nulos permanece íntegro (R12).

const ARQUIVO: String = "user://spec011_flow_test.json"

var gm: GameplayManager
var _chamadas: Array[String] = []


## Spy de ProgressManager — registra a ordem e delega ao domínio real.
class ProgressSpy extends ProgressManager:
	var chamadas: Array = []

	func processar_vitoria(
		modo: String, ambiente: String, distancia: float,
		perda_colisao: float, data_hora: String = ""
	) -> Dictionary:
		chamadas.append("processar_vitoria")
		return super.processar_vitoria(modo, ambiente, distancia, perda_colisao, data_hora)

	func processar_derrota(modo: String) -> Dictionary:
		chamadas.append("processar_derrota")
		return super.processar_derrota(modo)


## Spy de SaveManager — registra a gravação e delega ao I/O real.
class SaveSpy extends SaveManager:
	var chamadas: Array = []

	func _init(p_caminho: String, p_chamadas: Array) -> void:
		super(p_caminho)
		chamadas = p_chamadas

	func gravar(dados: Dictionary) -> bool:
		chamadas.append("gravar")
		return super.gravar(dados)


func before_test() -> void:
	_limpar()
	_chamadas = []
	gm = _montar_gm()
	GameState.reset()


func after_test() -> void:
	_desmontar_gm(gm)
	_limpar()
	GameState.reset()


func _limpar() -> void:
	if FileAccess.file_exists(ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	if FileAccess.file_exists(ARQUIVO + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO + ".tmp"))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ARQUIVO + ".tmp")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO + ".tmp"))


## SC-003 — vitória: exatamente 1 processamento + 1 gravação, na ordem
## pontuação/recorde (dentro do processar_vitoria) → save.
func test_01_vitoria_uma_chamada_na_ordem() -> void:
	_preparar_vitoria()
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	assert_int(_chamadas.size()).is_equal(2).override_failure_message(
		"Vitória deveria gerar exatamente [processar_vitoria, gravar]; veio %s" % str(_chamadas)
	)
	assert_str(_chamadas[0]).is_equal("processar_vitoria")
	assert_str(_chamadas[1]).is_equal("gravar")
	assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)


## SC-011 — repetir a avaliação em VICTORY não duplica processamento nem
## gravação (latch de estado).
func test_02_vitoria_sem_duplicar() -> void:
	_preparar_vitoria()
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	gm._avaliar_transicoes()
	assert_int(_chamadas.size()).is_equal(2)


## SC-011/FR-001 — derrota: processar_derrota + save, sem resultado novo
## e sem pontuação no snapshot.
func test_03_derrota_processa_e_grava_sem_resultado() -> void:
	var hist_antes: int = (gm.progress_manager.dados_para_salvar()["historico"] as Array).size()
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.player_vehicle.controller.speed = 0.0

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	assert_int(_chamadas.size()).is_equal(2)
	assert_str(_chamadas[0]).is_equal("processar_derrota")
	assert_str(_chamadas[1]).is_equal("gravar")
	var hist_depois: int = (gm.progress_manager.dados_para_salvar()["historico"] as Array).size()
	assert_int(hist_depois).is_equal(hist_antes)
	assert_int(GameState.current_state).is_equal(GameState.State.GAME_OVER)


## R12 — sem progress_manager/save_manager (sintético legado) a vitória e a
## derrota continuam funcionando sem crash.
func test_04_sem_managers_nao_quebra() -> void:
	gm.progress_manager = null
	gm.save_manager = null
	_preparar_vitoria()
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)


## Dados persistidos de verdade: a vitória grava recorde coerente no disco.
func test_05_vitoria_persiste_recorde_em_disco() -> void:
	_preparar_vitoria()
	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	var disco := SaveManager.new(ARQUIVO)
	var dados: Dictionary = disco.carregar()
	assert_bool(dados.has("modos")).is_true()
	var recorde: float = float(dados["modos"][gm.dificuldade.get_modo()]["recorde"])
	assert_bool(recorde >= 0.0).is_true()


func _preparar_vitoria() -> void:
	gm.track_manager.setup(5.0)
	gm.track_manager.reset()
	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()
	gm.track_layer.criar_marcadores(400.0, 0.05)
	gm.track_layer.banda_chegada.position.y = 430.0


func _montar_gm() -> GameplayManager:
	var gerente := GameplayManager.new()
	gerente.game_state = GameState
	gerente.fuel_system = FuelSystem.new()
	gerente.track_manager = TrackManager.new()
	gerente.track_layer = TrackMarkers.new()
	gerente.player_vehicle = PlayerVehicle.new()
	gerente.player_vehicle.sprite = Sprite2D.new()
	gerente.items_layer = FuelCanManager.new()
	gerente.items_layer.setup()
	var spy_p := ProgressSpy.new()
	spy_p.chamadas = _chamadas
	gerente.progress_manager = spy_p
	gerente.save_manager = SaveSpy.new(ARQUIVO, _chamadas)
	gerente.game_state.state_changed.connect(gerente._on_state_changed)
	return gerente


func _desmontar_gm(gerente: GameplayManager) -> void:
	gerente.fuel_system.free()
	gerente.track_manager.free()
	gerente.track_layer.free()
	gerente.player_vehicle.free()
	gerente.items_layer.free()
	if gerente.obstacles_layer != null:
		gerente.obstacles_layer.free()
	gerente.free()


## T040 / FR-023 + US4 AS9 — a ida ao MENU limpa os obstáculos da corrida
## anterior (espelha o reset dos galões): nenhum sprite residual flutuando
## sobre o fundo do menu.
func test_06_menu_limpa_obstaculos_residual() -> void:
	gm.obstacles_layer = ObstacleManager.new()
	gm.obstacles_layer.configurar()
	var item: Obstacle = gm.obstacles_layer.pool.pop_back()
	gm.obstacles_layer.ativos.append(item)
	item.definir_tipo(Obstacle.TIPO_POCA)
	item.ativar(Vector2(320.0, 432.0))
	assert_bool(gm.obstacles_layer.ativos.has(item)).is_true()

	gm._on_go_to_menu()

	assert_int(gm.obstacles_layer.ativos.size()).is_equal(0).override_failure_message(
		"Obstáculos residuais no caminho para o MENU (FR-023/US4 AS9)"
	)
	assert_bool(gm.obstacles_layer.pool.has(item)).is_true()


## T040 — o encerramento (vitória) também limpa os obstáculos, no mesmo
## ponto em que já limpa os galões.
func test_07_encerramento_limpa_obstaculos() -> void:
	gm.obstacles_layer = ObstacleManager.new()
	gm.obstacles_layer.configurar()
	_preparar_vitoria()
	var item: Obstacle = gm.obstacles_layer.pool.pop_back()
	gm.obstacles_layer.ativos.append(item)
	item.definir_tipo(Obstacle.TIPO_CASCALHO)
	item.ativar(Vector2(320.0, 432.0))

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()

	assert_int(gm.obstacles_layer.ativos.size()).is_equal(0).override_failure_message(
		"Encerramento deixou obstáculos ativos (FR-023 — espelha os galões)"
	)
	assert_bool(gm.obstacles_layer.pool.has(item)).is_true()
