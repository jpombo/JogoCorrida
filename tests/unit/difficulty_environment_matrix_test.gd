extends GdUnitTestSuite

## SPEC-009 / T022 (US4) — Matriz ambiente × modo (SC-011): os 4 ambientes
## × 3 modos — fatores de modo idênticos em qualquer ambiente (o modo nunca
## lê ambiente), características ambientais (penalidade base, taxa de
## galões por ambiente) intactas e alteradas APENAS pelos fatores do modo,
## e modos mutuamente independentes (trocar de modo não vaza estado).

var _ambientes: Array[String] = ["PLAINS", "DESERT", "FOREST", "ICE"]
var _modos: Array[String] = ["relaxing", "normal", "challenge"]


## F1 — os 5 fatores de modo não dependem do ambiente: idênticos na
## matriz inteira 4×3 (SC-011 — modo e ambiente ortogonais).
func test_01_fatores_de_modo_independentess_de_ambiente() -> void:
	var dm := DifficultyManager.new()
	var ambiente_original: String = String(GameConfig.current_environment_id)

	for modo in _modos:
		dm.definir_modo(modo)
		var referencia: Array[float] = [
			dm.fator_velocidade_total(),
			dm.fator_densidade(),
			dm.fator_frequencia_galoes(),
			dm.fator_penalidade_colisao(),
			dm.fator_distancia_galoes(),
		]
		for ambiente in _ambientes:
			GameConfig.current_environment_id = ambiente
			assert_float(dm.fator_velocidade_total()).is_equal(referencia[0])
			assert_float(dm.fator_densidade()).is_equal(referencia[1])
			assert_float(dm.fator_frequencia_galoes()).is_equal(referencia[2])
			assert_float(dm.fator_penalidade_colisao()).is_equal(referencia[3])
			assert_float(dm.fator_distancia_galoes()).is_equal(referencia[4])

	GameConfig.current_environment_id = ambiente_original
	dm = null


## F2 — penalidade efetiva = base do AMBIENTE × fator do MODO (SC-007/FR-010):
## a base por ambiente permanece intacta — o modo só escala.
func test_02_penalidade_matriz_ambiente_por_modo() -> void:
	var dm := DifficultyManager.new()
	var ambiente_original: String = String(GameConfig.current_environment_id)

	for ambiente in _ambientes:
		GameConfig.current_environment_id = ambiente
		var base: float = float(
			GameConfig.collision_fuel_penalty.get(ambiente, 0.0)
		)
		for modo in _modos:
			dm.definir_modo(modo)
			# A base nunca é mutada pelo modo (R1): a leitura segue igual.
			assert_float(
				float(GameConfig.collision_fuel_penalty.get(ambiente, 0.0))
			).is_equal(base)

	# Amostras conhecidas: ICE (base) × Desafio (1,5) e ICE × Relaxante (0,5).
	dm.definir_modo("challenge")
	var ice_base: float = float(GameConfig.collision_fuel_penalty.get("ICE", 0.0))
	assert_float(ice_base * dm.fator_penalidade_colisao()).is_equal_approx(
		ice_base * 1.5, 0.000001
	)
	dm.definir_modo("relaxing")
	assert_float(ice_base * dm.fator_penalidade_colisao()).is_equal_approx(
		ice_base * 0.5, 0.000001
	)

	GameConfig.current_environment_id = ambiente_original
	dm = null


## F3 — taxa de galões efetiva = taxa por AMBIENTE × frequencia do MODO: a
## matriz 4×3 preserva a ordem entre ambientes dentro de cada modo (a base
## por ambiente não vira) e a ordem entre modos dentro de cada ambiente.
func test_03_taxa_galoes_matriz_completa() -> void:
	var dm := DifficultyManager.new()
	var fm := FuelCanManager.new()
	fm.dificuldade = dm
	var ambiente_original: String = String(GameConfig.current_environment_id)
	var matriz: Dictionary = {}  # [ambiente][modo] = taxa

	for ambiente in _ambientes:
		GameConfig.current_environment_id = ambiente
		var base: float = float(
			GameConfig.fuel_can_spawn_rate.get(ambiente, 1.0)
		)
		var taxas_modo: Array[float] = []
		for modo in _modos:
			dm.definir_modo(modo)
			var taxa: float = fm._taxa_efetiva()
			matriz[ambiente + ":" + modo] = taxa
			# Ortogonalidade: base intacta, só o fator do modo compõe.
			assert_float(taxa).is_equal_approx(
				base * dm.fator_frequencia_galoes(), 0.000001
			)
			taxas_modo.append(taxa)
		# Ordem entre modos dentro do mesmo ambiente (SC-006).
		assert_bool(taxas_modo[0] > taxas_modo[1]).override_failure_message(
			"%s: Relaxante (%.3f) deveria superar Normal (%.3f)"
			% [ambiente, taxas_modo[0], taxas_modo[1]]
		)
		assert_bool(taxas_modo[1] > taxas_modo[2]).override_failure_message(
			"%s: Normal (%.3f) deveria superar Desafio (%.3f)"
			% [ambiente, taxas_modo[1], taxas_modo[2]]
		)

	# Ordem entre ambientes preservada dentro de cada modo (base não vira).
	for modo in _modos:
		var plas: float = matriz["PLAINS:" + modo]
		var ice: float = matriz["ICE:" + modo]
		assert_bool(plas > ice).override_failure_message(
			"modo %s: PLAINS (%.3f) deveria superar ICE (%.3f)" % [modo, plas, ice]
		)

	GameConfig.current_environment_id = ambiente_original
	fm.dificuldade = null
	fm.free()
	dm = null


## F4 — modos mutuamente independentes: ciclar não vaza estado entre
## trocas (efetiva(100) sempre = 100 × modo × ciclo corrente).
func test_04_modos_independentess() -> void:
	var dm := DifficultyManager.new()
	var esperados: Dictionary = {"relaxing": 1.0, "normal": 3.0, "challenge": 4.0}

	for i in 9:
		var modo: String = dm.ciclar_modo()
		assert_float(dm.efetiva(100.0)).is_equal_approx(
			100.0 * esperados[modo], 0.000001
		)
	dm = null
