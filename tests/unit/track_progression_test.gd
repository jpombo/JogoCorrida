extends GdUnitTestSuite

## SPEC-008 / testes obrigatórios A (início) + B (distância) — US2.
## TrackManager puro, sem árvore de cena: integração pela velocidade de
## avanço, monotonicidade, teto no total, variação real do sinal e
## independência da reciclagem da estrada (FR-005…FR-008, research R1).

var track: TrackManager
var _unidades_original: float
var _total_original: float

## Contadores de sinal — vars de membro porque lambdas do GDScript capturam
## inteiros por valor (o += não propaga para fora da lambda).
var _emissoes: int = 0
var _ultima_percorrida: float = -1.0


func before_test() -> void:
	_unidades_original = GameConfig.track_units_to_km
	_total_original = GameConfig.track_total_distance
	GameConfig.track_units_to_km = 0.00034722
	track = TrackManager.new()
	track.setup(5.0)
	track.reset()
	_emissoes = 0
	_ultima_percorrida = -1.0


func _contar_progresso(p: float, _t: float, _e: float) -> void:
	_emissoes += 1
	_ultima_percorrida = p


func after_test() -> void:
	GameConfig.track_units_to_km = _unidades_original
	GameConfig.track_total_distance = _total_original
	track.free()


## Teste A1 — reset nasce exatamente zerado e emite para o indicador de UI.
func test_a1_reset_zera_e_emite() -> void:
	assert_float(track.get_percorrida()).is_equal(0.0)
	assert_float(track.get_restante()).is_equal(5.0)
	assert_float(track.get_percentual()).is_equal(0.0)
	assert_bool(track.esta_concluido()).is_false()

	var emissões_antes: int = _emissoes
	track.progress_changed.connect(_contar_progresso)
	track.reset()
	assert_int(_emissoes).is_equal(emissões_antes + 1)
	assert_float(_ultima_percorrida).is_equal(0.0)


## Teste B1 — crescimento pela fórmula da velocidade de avanço (SC-002).
func test_b1_cresce_pela_velocidade() -> void:
	var delta: float = 1.0 / 60.0
	var esperado: float = 100.0 * GameConfig.track_units_to_km * delta
	track.update(delta, 100.0)
	assert_float(track.get_percorrida()).is_equal_approx(esperado, 0.0001)
	assert_float(track.get_restante()).is_equal_approx(5.0 - esperado, 0.0001)


## Teste B2 — parado não acumula distância (SC-003).
func test_b2_parado_nao_acumula() -> void:
	track.update(1.0, 0.0)
	assert_float(track.get_percorrida()).is_equal(0.0)
	track.update(1.0, -10.0)
	assert_float(track.get_percorrida()).is_equal(0.0)


## Teste B3 — mudança de faixa não conta: a distância só recebe a velocidade
## de AVANÇO passada ao update (Clarificação de faixa — "não cresce").
func test_b3_lateral_nao_acumula() -> void:
	# Cenário: jogador trocando de faixa (lateral 100 px/s) com avanço zero.
	track.update(1.0, 0.0)
	assert_float(track.get_percorrida()).is_equal(0.0)
	# Mesmo com avanço alto, a distância é exatamente a fórmula — sem
	# qualquer termo lateral.
	track.update(1.0, 50.0)
	assert_float(track.get_percorrida()).is_equal_approx(50.0 * GameConfig.track_units_to_km, 0.0001)


## Teste B4 — teto no total e monotonicidade (SC-004): nunca ultrapassa,
## nunca decresce.
func test_b4_teto_e_monotonicidade() -> void:
	track.update(100000.0, 1000.0)
	assert_float(track.get_percorrida()).is_equal(5.0)
	assert_float(track.get_restante()).is_equal(0.0)
	assert_float(track.get_percentual()).is_equal(1.0)
	var antes: float = track.get_percorrida()
	track.update(1.0, 100.0)
	assert_float(track.get_percorrida()).is_equal(antes)


## Teste B5 — independência da taxa de quadros: a mesma distância percorrida
## com deltas diferentes produz o mesmo resultado (SC-003).
func test_b5_independencia_de_delta() -> void:
	var outro := TrackManager.new()
	outro.setup(5.0)
	outro.reset()

	var passos_60: int = 60
	var passos_30: int = 30
	for i in passos_60:
		track.update(1.0 / 60.0, 100.0)
	for i in passos_30:
		outro.update(1.0 / 30.0, 100.0)

	assert_float(track.get_percorrida()).is_equal_approx(outro.get_percorrida(), 0.0001)
	outro.free()


## Teste B6 — o sinal emite APENAS em variação real (FR-007, data-model §2).
func test_b6_sinal_so_em_variacao() -> void:
	if not track.progress_changed.is_connected(_contar_progresso):
		track.progress_changed.connect(_contar_progresso)
	_emissoes = 0

	track.update(1.0 / 60.0, 0.0)      # sem avanço
	assert_int(_emissoes).is_equal(0)
	track.update(0.0, 100.0)           # delta zero
	assert_int(_emissoes).is_equal(0)
	track.update(1.0 / 60.0, 100.0)    # variação real
	assert_int(_emissoes).is_equal(1)


## Teste B7 — independência da reciclagem da estrada (FR-007): o
## TrackManager não lê Road nem scroll_offset; a distância é função da
## velocidade e do delta, idêntica com qualquer histórico de rolagem.
func test_b7_independente_da_estrada() -> void:
	var passos: int = 120
	var scroll_total := 0.0
	for i in passos:
		# Simula scroll arbitrário da estrada (reciclagem, freeze etc.) —
		# nenhum efeito no TrackManager.
		scroll_total += randf() * 500.0
		track.update(1.0 / 60.0, 100.0)
	var esperado: float = 100.0 * GameConfig.track_units_to_km * (1.0 / 60.0) * passos
	assert_float(track.get_percorrida()).is_equal_approx(esperado, 0.0001)
	assert_float(scroll_total).is_greater(0.0)


## marcar_concluido trava a corrida sem tocar na distância.
func test_marcar_concluido() -> void:
	assert_bool(track.esta_concluido()).is_false()
	track.marcar_concluido()
	assert_bool(track.esta_concluido()).is_true()
