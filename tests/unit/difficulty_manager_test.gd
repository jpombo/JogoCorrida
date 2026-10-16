extends GdUnitTestSuite

## SPEC-009 / T003 — DifficultyManager: modos e ordem do ciclo, fatores de
## cada modo, fallback Normal para modo inválido e fator de ciclo composto
## (data-model.md §2–§3, contracts/difficulty_manager_api.md §1, SC-012).

var dm: DifficultyManager


func before_test() -> void:
	dm = DifficultyManager.new()


func after_test() -> void:
	dm = null  # RefCounted — coletado automaticamente, sem free()


## SC-012 — modo padrão de arranque é "normal" (FR-001).
func test_01_modo_padrao_normal() -> void:
	assert_str(dm.get_modo()).is_equal(String(GameConfig.difficulty_default_mode))
	assert_str(dm.get_modo()).is_equal("normal")


## Fatores de cada modo — os 5 multiplicadores conforme data-model §2.
func test_02_fatores_relaxing() -> void:
	dm.definir_modo("relaxing")
	assert_float(dm.multiplicador_velocidade()).is_equal(1.0)
	assert_float(dm.fator_densidade()).is_equal(0.70)
	assert_float(dm.fator_frequencia_galoes()).is_equal(1.50)
	assert_float(dm.fator_penalidade_colisao()).is_equal(0.50)
	assert_float(dm.fator_distancia_galoes()).is_equal(0.80)


func test_03_fatores_normal() -> void:
	dm.definir_modo("normal")
	assert_float(dm.multiplicador_velocidade()).is_equal(3.0)
	assert_float(dm.fator_densidade()).is_equal(1.00)
	assert_float(dm.fator_frequencia_galoes()).is_equal(1.00)
	assert_float(dm.fator_penalidade_colisao()).is_equal(1.00)
	assert_float(dm.fator_distancia_galoes()).is_equal(1.00)


func test_04_fatores_challenge() -> void:
	dm.definir_modo("challenge")
	assert_float(dm.multiplicador_velocidade()).is_equal(4.0)
	assert_float(dm.fator_densidade()).is_equal(1.20)
	assert_float(dm.fator_frequencia_galoes()).is_equal(0.65)
	assert_float(dm.fator_penalidade_colisao()).is_equal(1.50)
	assert_float(dm.fator_distancia_galoes()).is_equal(1.20)


## Ordem do ciclo: relaxing → normal → challenge → relaxing (FR-002).
func test_05_ordem_do_ciclo() -> void:
	dm.definir_modo("relaxing")
	assert_str(dm.ciclar_modo()).is_equal("normal")
	assert_str(dm.ciclar_modo()).is_equal("challenge")
	assert_str(dm.ciclar_modo()).is_equal("relaxing")


## Modo inválido → default "normal" com os fatores de Normal (FR-001).
func test_06_fallback_normal_para_modo_invalido() -> void:
	dm.definir_modo("inexistente")
	assert_str(dm.get_modo()).is_equal("normal")
	assert_float(dm.multiplicador_velocidade()).is_equal(3.0)

	dm.definir_modo("relaxing")
	dm.definir_modo("")  # string vazia também cai no default
	assert_str(dm.get_modo()).is_equal("normal")


## Fator de ciclo: ciclo 1 = 1,000; composto por incremento configurável
## (SC-016, environment_cycle.md §4).
func test_07_fator_ciclo() -> void:
	assert_float(dm.fator_ciclo()).is_equal(1.0)

	dm.aplicar_fator_ciclo(1.0 + 0.002 * 3)
	assert_float(dm.fator_ciclo()).is_equal_approx(1.006, 0.0001)

	# Valor não positivo é descartado (fallback seguro).
	dm.aplicar_fator_ciclo(0.0)
	assert_float(dm.fator_ciclo()).is_equal(1.0)


## fator_velocidade_total = multiplicador do modo × fator de ciclo.
func test_08_velocidade_total_composta() -> void:
	dm.definir_modo("normal")
	assert_float(dm.fator_velocidade_total()).is_equal(3.0)

	dm.aplicar_fator_ciclo(1.1)
	assert_float(dm.fator_velocidade_total()).is_equal_approx(3.3, 0.0001)


## efetiva(base) = base × fator_velocidade_total().
func test_09_efetiva() -> void:
	dm.definir_modo("challenge")  # 4,0 × ciclo 1,0
	assert_float(dm.efetiva(100.0)).is_equal(400.0)

	dm.aplicar_fator_ciclo(1.05)
	assert_float(dm.efetiva(100.0)).is_equal_approx(420.0, 0.0001)


## Regressão R12: Relaxante no ciclo 1 → todos os fatores efetivos = 1,0
## (comportamento idêntico ao atual — prova de não-regressão).
func test_10_relaxante_ciclo_um_identico_ao_atual() -> void:
	dm.definir_modo("relaxing")
	assert_float(dm.fator_velocidade_total()).is_equal(1.0)
	assert_float(dm.fator_densidade()).is_equal(0.70)
	# Densidade Relaxante é 0,70 por design; os fatores "de velocidade"
	# e o fator de ciclo são os que precisam ser exatamente 1,0.
	assert_float(dm.fator_ciclo()).is_equal(1.0)
	assert_float(dm.multiplicador_velocidade()).is_equal(1.0)


## Ciclar a partir de um modo inválido retoma o ciclo pela trilha válida.
func test_11_ciclar_apos_modo_invalido() -> void:
	dm.definir_modo("qualquer")
	assert_str(dm.get_modo()).is_equal("normal")
	assert_str(dm.ciclar_modo()).is_equal("challenge")
