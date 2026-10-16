extends GdUnitTestSuite

## SPEC-009 / T017 (US3) — Densidade de trânsito e frequência de galões
## pelo modo (SC-005/SC-006, FR-007/FR-008): densidade Relaxante < Normal <
## Desafio sempre dentro de `traffic_min_visible..traffic_max_vehicles`
## (limites absolutos intactos nos extremos); frequência de galões
## Relaxante > Normal > Desafio com intervalo efetivo sempre > 0; sem
## injeção tudo cai nos valores legados 1,0 (R12).

## Teto legado do PLAINS (dificuldade 1) para comparações.
var _teto_plains: int


func before_test() -> void:
	_teto_plains = _teto_legado_plains()


func test_01_densidade_crescente_na_faixa_absoluta() -> void:
	var tm := TrafficManager.new()
	# Sem injeção: teto legado intacto (R12).
	tm.fator_dificuldade = 1.0
	assert_int(tm._maximo_visivel_atual()).is_equal(_teto_plains)

	# Relaxante (0,70) < Normal (1,0) < Desafio (1,2) — mesmo ambiente.
	tm.fator_dificuldade = 0.70
	var relaxing: int = tm._maximo_visivel_atual()
	tm.fator_dificuldade = 1.0
	var normal: int = tm._maximo_visivel_atual()
	tm.fator_dificuldade = 1.20
	var desafio: int = tm._maximo_visivel_atual()

	assert_bool(relaxing < normal).override_failure_message(
		"Relaxante (%d) deveria ser menos denso que Normal (%d)" % [relaxing, normal]
	)
	assert_bool(normal < desafio).override_failure_message(
		"Normal (%d) deveria ser menos denso que Desafio (%d)" % [normal, desafio]
	)

	# Todo modo respeita os limites absolutos (SC-005).
	for fator in [0.70, 1.0, 1.2]:
		tm.fator_dificuldade = fator
		var maximo: int = tm._maximo_visivel_atual()
		assert_bool(maximo >= GameConfig.traffic_min_visible).override_failure_message(
			"fator %.2f violou o piso: %d < %d" % [fator, maximo, GameConfig.traffic_min_visible]
		)
		assert_bool(maximo <= GameConfig.traffic_max_vehicles).override_failure_message(
			"fator %.2f violou o teto: %d > %d" % [fator, maximo, GameConfig.traffic_max_vehicles]
		)
	tm.free()


## Piso/teto intactos nos extremos: fator absurdo nunca quebra os limites
## globais (SC-005 — clamp incondicional).
func test_02_extremos_nao_violam_limites() -> void:
	var tm := TrafficManager.new()
	tm.fator_dificuldade = 0.01
	assert_int(tm._maximo_visivel_atual()).is_equal(GameConfig.traffic_min_visible)
	tm.fator_dificuldade = 999.0
	assert_int(tm._maximo_visivel_atual()).is_equal(GameConfig.traffic_max_vehicles)
	tm.free()


## Frequência de galões: Relaxante > Normal > Desafio (SC-006) — taxa
## crescente com `frequencia_galoes` e intervalo crescente com
## `distancia_galoes`; intervalo efetivo sempre > 0.
func test_03_frequencia_galoes_por_modo() -> void:
	var dm := DifficultyManager.new()
	var fm := FuelCanManager.new()

	dm.definir_modo("relaxing")
	fm.dificuldade = dm
	var taxa_relax: float = fm._taxa_efetiva()
	var intervalo_relax: float = fm._intervalo_efetiva(taxa_relax)

	dm.definir_modo("normal")
	var taxa_normal: float = fm._taxa_efetiva()
	var intervalo_normal: float = fm._intervalo_efetiva(taxa_normal)

	dm.definir_modo("challenge")
	var taxa_desafio: float = fm._taxa_efetiva()
	var intervalo_desafio: float = fm._intervalo_efetiva(taxa_desafio)

	assert_bool(taxa_relax > taxa_normal).override_failure_message(
		"Taxa Relaxante (%.3f) deveria superar Normal (%.3f)" % [taxa_relax, taxa_normal]
	)
	assert_bool(taxa_normal > taxa_desafio).override_failure_message(
		"Taxa Normal (%.3f) deveria superar Desafio (%.3f)" % [taxa_normal, taxa_desafio]
	)
	assert_bool(intervalo_relax > 0.0 and intervalo_normal > 0.0 and intervalo_desafio > 0.0)

	# Ordem efetiva de nascimento: taxa/intervalo Relaxante supera Normal
	# que supera Desafio (frequencia_galoes > e distancia_galoes <).
	assert_bool(intervalo_relax < intervalo_normal).override_failure_message(
		"Intervalo Relaxante (%.3f) deveria ser menor que Normal (%.3f)"
		% [intervalo_relax, intervalo_normal]
	)
	assert_bool(intervalo_normal < intervalo_desafio).override_failure_message(
		"Intervalo Normal (%.3f) deveria ser menor que Desafio (%.3f)"
		% [intervalo_normal, intervalo_desafio]
	)

	# Base por ambiente intacta: relaxing = base × 1,5 (FR-008, R12).
	var base: float = float(
		GameConfig.fuel_can_spawn_rate.get(GameConfig.current_environment_id, 1.0)
	)
	assert_float(taxa_relax).is_equal_approx(base * 1.5, 0.000001)

	fm.dificuldade = null
	fm.free()
	dm = null


## Sem injeção os galões ficam na taxa/intervalo legados do ambiente
## corrente (R12) e a densidade no teto do ambiente — regressão zero da
## SPEC-004/008.
func test_04_sem_injecao_valores_legados() -> void:
	var ambiente_original: String = String(GameConfig.current_environment_id)
	GameConfig.current_environment_id = "PLAINS"

	var fm := FuelCanManager.new()
	# Taxa legada = taxa por ambiente (PLAINS 1,4 — SEM fator de modo).
	assert_float(fm._taxa_efetiva()).is_equal_approx(1.4, 0.000001)
	assert_float(fm._intervalo_efetiva(fm._taxa_efetiva())).is_equal_approx(
		GameConfig.fuel_can_spawn_interval_distance / 1.4, 0.000001
	)
	fm.free()

	var tm := TrafficManager.new()
	assert_int(tm._maximo_visivel_atual()).is_equal(_teto_plains)
	tm.free()

	GameConfig.current_environment_id = ambiente_original


## Teto legado do ambiente PLAINS (mesma leitura de
## `_maximo_visivel_atual` sem fator).
func _teto_legado_plains() -> int:
	var ambiente: Dictionary = GameConfig.ENVIRONMENTS.get("PLAINS", {})
	var nivel: int = int(ambiente.get("difficulty", 1))
	return int(
		GameConfig.traffic_max_visible_by_difficulty.get(
			nivel, GameConfig.traffic_min_visible
		)
	)
