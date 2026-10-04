extends GdUnitTestSuite

## T016 — categorias de trânsito: conversão de velocidade (FR-008, I4),
## existência dos assets na pasta exclusiva (FR-012) e soma das frequências
## (FR-010, FR-023). T040 acrescenta as invariantes de configuração do
## trânsito, que vivem aqui porque são propriedades do mesmo dicionário.

const ESPERADAS: int = 4


func _categorias() -> Array[TrafficData]:
	var lista: Array[TrafficData] = []
	for id in GameConfig.TRAFFIC_CATEGORIES:
		lista.append(TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id]))
	return lista


func test_four_categories_declared() -> void:
	assert_int(GameConfig.TRAFFIC_CATEGORIES.size()).is_equal(
		ESPERADAS
	).override_failure_message("FR-001: são 4 categorias de veículo")


func test_max_speed_is_kmh_times_factor() -> void:
	for c in _categorias():
		var esperado: float = c.max_speed_kmh * GameConfig.KMH_TO_SPEED_UNIT
		assert_float(c.max_speed).is_equal(esperado).override_failure_message(
			"FR-008: max_speed deve ser max_speed_kmh * KMH_TO_SPEED_UNIT (%s)" % c.id
		)


func test_all_categories_slower_than_player() -> void:
	for c in _categorias():
		assert_bool(c.is_slower_than_player()).is_true().override_failure_message(
			"FR-008/I4: categoria %s não é mais lenta que o jogador" % c.id
		)


func test_assets_files_exist_in_own_folder() -> void:
	for c in _categorias():
		assert_bool(c.assets.is_empty()).is_false().override_failure_message(
			"FR-012: categoria %s sem assets" % c.id
		)
		for nome in c.assets:
			var caminho: String = c.texture_path_for(nome)
			assert_bool(ResourceLoader.exists(caminho)).is_true().override_failure_message(
				"FR-012: asset ausente em %s -> %s" % [c.assets_path, caminho]
			)


func test_frequency_sum_greater_than_zero() -> void:
	var soma: float = 0.0
	for c in _categorias():
		assert_bool(c.frequency >= 0.0).is_true().override_failure_message(
			"FR-023: frequência negativa em %s" % c.id
		)
		soma += c.frequency
	assert_float(soma).is_greater(0.0).override_failure_message(
		"FR-010: soma das frequências deve ser positiva"
	)


func test_categories_are_spawnable() -> void:
	for c in _categorias():
		assert_bool(c.is_spawnable()).is_true().override_failure_message(
			"FR-023: categoria %s não é sorteável" % c.id
		)


## T040 — invariantes de configuração do trânsito (FR-004, FR-019, FR-023).
func test_traffic_config_invariants() -> void:
	assert_float(GameConfig.traffic_spawn_interval).is_greater(0.0).override_failure_message(
		"T040: traffic_spawn_interval deve ser positivo"
	)
	assert_float(GameConfig.traffic_min_spacing).is_greater(0.0).override_failure_message(
		"T040: traffic_min_spacing deve ser positivo"
	)
	assert_float(GameConfig.traffic_spawn_distance).is_greater(0.0).override_failure_message(
		"T040: traffic_spawn_distance deve ser positivo"
	)
	assert_int(GameConfig.traffic_max_vehicles).is_greater(0).override_failure_message(
		"T040: traffic_max_vehicles deve ser positivo"
	)
	assert_float(GameConfig.KMH_TO_SPEED_UNIT).is_greater(0.0).override_failure_message(
		"T040: KMH_TO_SPEED_UNIT deve ser positivo"
	)


## T040 — a frequência de cada categoria é exposta em traffic_tuning (FR-061).
func test_traffic_tuning_exposes_frequencies() -> void:
	GameConfig._build_tuning_groups()
	assert_dict(GameConfig.traffic_tuning).contains_keys(
		"traffic_frequency_passeio"
	).override_failure_message("FR-061: traffic_tuning sem a frequência de passeio")
	assert_dict(GameConfig.traffic_tuning).contains_keys(
		["traffic_enabled", "traffic_max_vehicles", "traffic_min_spacing"]
	).override_failure_message("FR-061: traffic_tuning incompleto")


## T062 / SC-004, US2/AC1, FR-010 — a proporção OBSERVADA das quatro categorias
## numa simulação prolongada aproxima-se das `frequency` declaradas. É o
## equivalente de trânsito ao cenário V17 da decoração (T056): o sorteio
## ponderado é exercitado milhares de vezes e a distribuição medida precisa
## cair dentro da tolerância estatística do declarado.
func test_observed_category_frequency_matches_declared() -> void:
	var manager: TrafficManager = TrafficManager.new()
	var categorias := {}
	for id in GameConfig.TRAFFIC_CATEGORIES:
		categorias[id] = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	manager.setup(categorias)

	# O sorteio (_sortear_categoria) é a lógica determinística isolada — a
	# simulação quadro a quadro com movimento dependeria do ritmo de reciclagem
	# e a medição estatística sairia ruidosa sem necessidade.
	var total: int = 20000
	var contagem := {}
	for i in total:
		var sorteada: TrafficData = manager._sortear_categoria()
		assert_object(sorteada).is_not_null().override_failure_message(
			"FR-010: sorteio devolveu null com todas as categorias sorteáveis"
		)
		contagem[sorteada.id] = int(contagem.get(sorteada.id, 0)) + 1

	# Tolerância de 2 pontos percentuais: com 20 mil sorteios o desvio-padrão
	# da leitura é ~0,34 p.p. no pior caso, então 2 p.p. é ~6σ.
	var tolerancia: float = 0.02
	var soma_declarada: float = 0.0
	for c in _categorias():
		soma_declarada += c.frequency

	for c in _categorias():
		var esperado: float = c.frequency / soma_declarada
		var observado: float = float(contagem.get(c.id, 0)) / float(total)
		assert_float(absf(observado - esperado)).is_less_equal(tolerancia).override_failure_message(
			"SC-004: %s declarou %.1f%% e observou %.1f%% em %d sorteios"
			% [c.id, esperado * 100.0, observado * 100.0, total]
		)

	manager.free()
