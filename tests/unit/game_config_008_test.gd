extends GdUnitTestSuite

## SPEC-008 / teste obrigatório I (configuração) — US8.
## Bloco de configuração completo e único (FR-039, SC-016): campos com tipos e
## valores de origem, efeitos observáveis sem tocar na lógica, ordem das
## taxas por ambiente e rótulos externalizados (FR-041, §VI).

var _total_original: float
var _por_km_original: float
var _margem_original: float
var _restore_original: float
var _intervalo_original: float
var _min_spacing_original: float
var _npc_spacing_original: float
var _start_original: float
var _finish_original: float
var _max_active_original: int
var _min_race_original: int
var _max_race_original: int
var _rate_original: Dictionary
var _unidades_original: float
var _ui_original: Dictionary


func before_test() -> void:
	_total_original = GameConfig.track_total_distance
	_por_km_original = GameConfig.fuel_consumption_per_distance
	_margem_original = GameConfig.fuel_safety_margin
	_restore_original = GameConfig.fuel_can_restore_amount
	_intervalo_original = GameConfig.fuel_can_spawn_interval_distance
	_min_spacing_original = GameConfig.fuel_can_min_spacing
	_npc_spacing_original = GameConfig.fuel_can_npc_spacing
	_start_original = GameConfig.fuel_can_start_offset
	_finish_original = GameConfig.fuel_can_finish_offset
	_max_active_original = GameConfig.fuel_can_max_active
	_min_race_original = GameConfig.fuel_can_min_per_race
	_max_race_original = GameConfig.fuel_can_max_per_race
	_rate_original = GameConfig.fuel_can_spawn_rate.duplicate()
	_unidades_original = GameConfig.track_units_to_km
	_ui_original = GameConfig.ui_strings.duplicate()


func after_test() -> void:
	GameConfig.track_total_distance = _total_original
	GameConfig.fuel_consumption_per_distance = _por_km_original
	GameConfig.fuel_safety_margin = _margem_original
	GameConfig.fuel_can_restore_amount = _restore_original
	GameConfig.fuel_can_spawn_interval_distance = _intervalo_original
	GameConfig.fuel_can_min_spacing = _min_spacing_original
	GameConfig.fuel_can_npc_spacing = _npc_spacing_original
	GameConfig.fuel_can_start_offset = _start_original
	GameConfig.fuel_can_finish_offset = _finish_original
	GameConfig.fuel_can_max_active = _max_active_original
	GameConfig.fuel_can_min_per_race = _min_race_original
	GameConfig.fuel_can_max_per_race = _max_race_original
	GameConfig.fuel_can_spawn_rate = _rate_original
	GameConfig.track_units_to_km = _unidades_original
	GameConfig.ui_strings = _ui_original


## I1 — o bloco SPEC-008 existe com os tipos esperados (data-model §6).
func test_i1_campos_existem_e_tipos() -> void:
	assert_bool(GameConfig.track_total_distance is float).is_true()
	assert_bool(GameConfig.track_units_to_km is float).is_true()
	assert_bool(GameConfig.fuel_consumption_per_distance is float).is_true()
	assert_bool(GameConfig.fuel_safety_margin is float).is_true()
	assert_bool(GameConfig.fuel_can_restore_amount is float).is_true()
	assert_bool(GameConfig.fuel_can_spawn_interval_distance is float).is_true()
	assert_bool(GameConfig.fuel_can_min_spacing is float).is_true()
	assert_bool(GameConfig.fuel_can_npc_spacing is float).is_true()
	assert_bool(GameConfig.fuel_can_start_offset is float).is_true()
	assert_bool(GameConfig.fuel_can_finish_offset is float).is_true()
	assert_bool(GameConfig.fuel_can_max_active is int).is_true()
	assert_bool(GameConfig.fuel_can_min_per_race is int).is_true()
	assert_bool(GameConfig.fuel_can_max_per_race is int).is_true()
	assert_bool(GameConfig.fuel_can_spawn_rate is Dictionary).is_true()
	assert_bool(GameConfig.ui_strings is Dictionary).is_true()


## I2 — invariantes de configuração: piso ≤ teto, offsets coerentes, taxas
## positivas e os quatro ambientes cadastrados (SC-010).
func test_i2_invariantes() -> void:
	assert_bool(GameConfig.fuel_can_min_per_race <= GameConfig.fuel_can_max_per_race).is_true()
	assert_bool(GameConfig.fuel_can_start_offset >= 0.0).is_true()
	assert_bool(GameConfig.fuel_can_finish_offset >= 0.0).is_true()
	assert_bool(GameConfig.track_units_to_km > 0.0).is_true()
	assert_bool(GameConfig.fuel_can_max_active > 0).is_true()
	for ambiente in ["PLAINS", "DESERT", "FOREST", "ICE"]:
		assert_bool(GameConfig.fuel_can_spawn_rate.has(ambiente)).is_true()
		assert_bool(float(GameConfig.fuel_can_spawn_rate[ambiente]) > 0.0).is_true()


## I3 — ordem das taxas: planície > deserto > floresta > gelo (SC-010) — a
## dificuldade vira frequência sem tocar na lógica de geração.
func test_i3_ordem_das_taxas() -> void:
	var plains: float = GameConfig.fuel_can_spawn_rate["PLAINS"]
	var desert: float = GameConfig.fuel_can_spawn_rate["DESERT"]
	var forest: float = GameConfig.fuel_can_spawn_rate["FOREST"]
	var ice: float = GameConfig.fuel_can_spawn_rate["ICE"]
	assert_bool(plains > desert).is_true()
	assert_bool(desert > forest).is_true()
	assert_bool(forest > ice).is_true()


## I4 — `track_total_distance` é a fonte única do total da corrida (SC-016).
func test_i4_distancia_fonte_unica() -> void:
	GameConfig.track_total_distance = 3.5
	var track := TrackManager.new()
	track.setup(GameConfig.track_total_distance)
	track.reset()
	assert_float(track.get_total()).is_equal(3.5)
	track.free()


## I5 — `fuel_can_restore_amount` é o valor emitido por coleta (global).
func test_i5_restore_amount_global() -> void:
	GameConfig.fuel_can_restore_amount = 40.0
	var sistema := FuelSystem.new()
	sistema.reset()
	sistema.definir_capacidade_derivada(200.0)
	sistema.reset()
	sistema.update(30.0, 100.0)  # drena ~60 ⇒ sobra ~140, folga p/ restaurar
	var antes: float = sistema.get_atual()
	sistema.restaurar(GameConfig.fuel_can_restore_amount)
	assert_float(sistema.get_atual()).is_equal_approx(antes + 40.0, 0.0001)
	sistema.free()


## I6 — rótulos externalizados e não vazios (FR-041, §VI); o template de
## distância aceita dois floats.
func test_i6_rotulos_externalizados() -> void:
	var chaves_essenciais := [
		"menu_title", "select_vehicle", "vehicle_blue", "vehicle_red",
		"start_race", "marker_start", "marker_finish", "distance_format",
		"victory", "game_over", "continue_race", "restart_race",
		"try_again", "back_to_menu", "paused",
	]
	for chave in chaves_essenciais:
		assert_bool(GameConfig.ui_strings.has(chave)).is_true()
		assert_bool(String(GameConfig.ui_strings[chave]).is_empty()).is_false()

	var texto: String = String(GameConfig.ui_strings.get("distance_format", "")) % [1.5, 5.0]
	assert_bool(texto.contains("1.5")).is_true()
	assert_bool(texto.contains("5.0")).is_true()


## I7 — sem literais de usuário na lógica: os módulos de UI/marcadores leem
## GameConfig.ui_strings, não strings fixas próprias (contrato estrutural —
## espelha a auditoria de configuração da SPEC-004). Comentários são ignorados.
func test_i7_sem_literais_nos_modulos() -> void:
	var fontes := [
		"res://src/ui/ui_manager.gd",
		"res://src/track/track_markers.gd",
	]
	for caminho in fontes:
		var texto: String = FileAccess.get_file_as_string(caminho)
		assert_bool(texto.contains("GameConfig.ui_strings")).is_true()
		var codigo := ""
		for linha in texto.split("\n"):
			var limpa: String = linha.strip_edges()
			if not limpa.begins_with("#"):
				codigo += limpa + "\n"
		# Rótulos conhecidos não podem aparecer como literal de STRING no
		# código (identificadores e enums com o mesmo nome são permitidos).
		for proibido in ["\"INÍCIO\"", "\"CHEGADA\"", "\"Continuar\"", "\"Vitória\"", "\"Fim de jogo\""]:
			assert_bool(codigo.contains(proibido)).is_false()
