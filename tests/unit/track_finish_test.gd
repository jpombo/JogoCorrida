extends GdUnitTestSuite

## SPEC-008 / teste obrigatório C (chegada) — US2/US3.
## TrackMarkers: posicionamento único, rolagem compartilhada, ocultamento
## definitivo do INÍCIO (SC-002), banda com primitivas configuradas e
## geometria de vitória; GameplayManager sintético para os cenários de
## transição (SC-005: 1×; combustível zero ⇒ sem vitória; fora de PLAYING
## ⇒ sem avaliação — FR-011…FR-013, research R2/R9).

var markers: TrackMarkers
var _unidades_original: float
var _player_y_original: float

## Contadores de sinal — vars de membro (lambdas capturam int por valor).
var _vitorias: int = 0
var _derrotas: int = 0


func before_test() -> void:
	_unidades_original = GameConfig.track_units_to_km
	GameConfig.track_units_to_km = 0.00034722
	markers = TrackMarkers.new()
	add_child(markers)
	GameState.reset()
	_vitorias = 0
	_derrotas = 0


func _contar_vitoria() -> void:
	_vitorias += 1


func _contar_derrota() -> void:
	_derrotas += 1


func after_test() -> void:
	GameConfig.track_units_to_km = _unidades_original
	GameState.reset()
	markers.queue_free()


## C1 — posicionamento: INÍCIO na largada, CHEGADA a `total / unidades` px
## acima (R2).
func test_c1_posicionamento_unico() -> void:
	markers.criar_marcadores(400.0, 5.0)
	assert_bool(markers.banda_inicio != null).is_true()
	assert_bool(markers.banda_chegada != null).is_true()
	assert_float(markers.banda_inicio.position.y).is_equal(400.0)
	var esperado: float = 400.0 - 5.0 / GameConfig.track_units_to_km
	# position.y é float32 (Vector2) — tolerância compatível com a precisão.
	assert_float(markers.banda_chegada.position.y).is_equal_approx(esperado, 0.01)


## C2 — as bandas descem com a MESMA rolagem da estrada (FR-011).
func test_c2_rolagem_compartilhada() -> void:
	markers.criar_marcadores(400.0, 0.05)
	var dy: float = 100.0 * 0.1
	var y_inicio: float = markers.banda_inicio.position.y
	var y_chegada: float = markers.banda_chegada.position.y
	markers.update(0.1, 100.0)
	assert_float(markers.banda_inicio.position.y).is_equal_approx(y_inicio + dy, 0.01)
	assert_float(markers.banda_chegada.position.y).is_equal_approx(y_chegada + dy, 0.01)


## C3 — pausa: sem update, as posições ficam idênticas (SC-012).
func test_c3_pausa_congela() -> void:
	markers.criar_marcadores(400.0, 0.05)
	markers.update(0.1, 100.0)
	var y_chegada: float = markers.banda_chegada.position.y
	# Quadro "de pausa": o manager não chama update (rolagem zerada).
	assert_float(markers.banda_chegada.position.y).is_equal(y_chegada)


## C4 — INÍCIO sai da tela e some DEFINITIVAMENTE (FR-010, SC-002).
func test_c4_inicio_some_definitivamente() -> void:
	markers.criar_marcadores(400.0, 5.0)
	markers.update(1.0, 5000.0)
	assert_bool(markers.banda_inicio.visible).is_false()
	var y_oculto: float = markers.banda_inicio.position.y
	markers.update(1.0, 5000.0)
	assert_bool(markers.banda_inicio.visible).is_false()
	assert_float(markers.banda_inicio.position.y).is_equal(y_oculto)
	# A chegada permanece.
	assert_bool(markers.banda_chegada != null).is_true()


## C5 — banda quadriculada com primitivas ColorRect e rótulo de GameConfig
## (FR-020: sem sprite novo; FR-041: texto externalizado).
func test_c5_primitivas_e_rotulos() -> void:
	markers.criar_marcadores(400.0, 5.0)
	var celulas := 0
	for filho in markers.banda_inicio.get_children():
		if filho is ColorRect:
			celulas += 1
	assert_int(celulas).is_greater(0)

	var rotulos := []
	for filho in markers.banda_inicio.get_children():
		if filho is Label:
			rotulos.append(filho.text)
	assert_bool(rotulos.has(String(GameConfig.ui_strings.get("marker_start", "")))).is_true()

	var rotulos_chegada := []
	for filho in markers.banda_chegada.get_children():
		if filho is Label:
			rotulos_chegada.append(filho.text)
	assert_bool(
		rotulos_chegada.has(String(GameConfig.ui_strings.get("marker_finish", "")))
	).is_true()


## C6 — geometria de vitória: só quando a banda está COMPLETAMENTE abaixo da
## base do jogador (R2, caso de borda 14).
func test_c6_geometria_cruzamento() -> void:
	markers.criar_marcadores(400.0, 5.0)
	var base_jogador: float = 400.0 + GameConfig.player_hitbox_size.y * 0.5

	markers.banda_chegada.position.y = base_jogador - 1.0
	assert_bool(markers.banda_completamente_cruzou(400.0, GameConfig.player_hitbox_size.y)).is_false()

	markers.banda_chegada.position.y = base_jogador
	assert_bool(markers.banda_completamente_cruzou(400.0, GameConfig.player_hitbox_size.y)).is_true()


## C7 — cenário de vitória: PLAYING + combustível positivo + cruzamento ⇒
## VICTORY com race_won emitido UMA vez (SC-005).
func test_c7_vitoria_uma_vez() -> void:
	var gm := _montar_gm()
	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()
	gm.track_layer.criar_marcadores(400.0, 0.05)
	gm.track_layer.banda_chegada.position.y = 430.0

	gm.race_won.connect(_contar_vitoria)

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(_vitorias).is_equal(1)
	assert_int(GameState.current_state).is_equal(GameState.State.VICTORY)

	# Segunda avaliação não repete (track concluído + estado já VICTORY).
	gm._avaliar_transicoes()
	assert_int(_vitorias).is_equal(1)
	_desmontar_gm(gm)


## C8 — combustível zero ⇒ SEM vitória (o esgotamento tem precedência e o
## cruzamento sozinho não basta — FR-013, caso de borda 1).
func test_c8_sem_vitoria_sem_combustivel() -> void:
	var gm := _montar_gm()
	gm.fuel_system.definir_capacidade_derivada(0.0)
	gm.fuel_system.reset()
	gm.track_layer.criar_marcadores(400.0, 0.05)
	gm.track_layer.banda_chegada.position.y = 430.0

	gm.race_won.connect(_contar_vitoria)
	gm.race_lost.connect(_contar_derrota)

	GameState.change_state(GameState.State.PLAYING)
	gm._avaliar_transicoes()
	assert_int(_vitorias).is_equal(0)
	_desmontar_gm(gm)


## C9 — fora de PLAYING não há avaliação (R9: o passo 6 só roda no ramo).
func test_c9_fora_de_playing_sem_avaliacao() -> void:
	var gm := _montar_gm()
	gm.fuel_system.definir_capacidade_derivada(100.0)
	gm.fuel_system.reset()
	gm.track_layer.criar_marcadores(400.0, 0.05)
	gm.track_layer.banda_chegada.position.y = 430.0

	gm.race_won.connect(_contar_vitoria)
	gm.race_lost.connect(_contar_derrota)

	# Estado MENU (fora de PLAYING): cruzamento "completo" não transiciona.
	GameState.change_state(GameState.State.MENU)
	gm._avaliar_transicoes()
	assert_int(_vitorias).is_equal(0)
	assert_int(_derrotas).is_equal(0)
	assert_int(GameState.current_state).is_equal(GameState.State.MENU)
	_desmontar_gm(gm)


## Monta um GameplayManager sintético, fora da árvore de cena, apenas com os
## campos que `_avaliar_transicoes` consulta (padrão das suítes anteriores).
func _montar_gm() -> GameplayManager:
	var gm := GameplayManager.new()
	gm.game_state = GameState
	gm.fuel_system = FuelSystem.new()
	gm.track_manager = TrackManager.new()
	gm.track_layer = TrackMarkers.new()
	gm.player_vehicle = PlayerVehicle.new()
	gm.track_manager.setup(5.0)
	gm.track_manager.reset()
	return gm


func _desmontar_gm(gm: GameplayManager) -> void:
	gm.fuel_system.free()
	gm.track_manager.free()
	gm.track_layer.free()
	gm.player_vehicle.free()
	gm.free()
