extends GdUnitTestSuite

## SPEC-009 / T012 (US2) — RaceProgression: sequência `environment_sequence`
## % size (gelo → planície), `registra_vitoria` (4 vitórias → ciclo+1 e
## posição 0), `zerar_ciclo_por_derrota` (pos=0, vitorias=0, ciclos
## preservados) e `fator_ciclo = 1 + incremento × ciclos`
## (data-model.md §4, contracts/environment_cycle.md §1–§2, SC-015–017).

var progresso: RaceProgression


func before_test() -> void:
	progresso = RaceProgression.new()


func after_test() -> void:
	progresso = null  # RefCounted — coletado automaticamente


## Estado inicial: planície, ciclo 1, sem bônus (SC-015).
func test_01_estado_inicial() -> void:
	assert_int(progresso.posicao).is_equal(0)
	assert_int(progresso.vitorias_ciclo).is_equal(0)
	assert_int(progresso.ciclos_concluidos).is_equal(0)
	assert_str(progresso.ambiente_atual()).is_equal("PLAINS")
	assert_float(progresso.fator_ciclo()).is_equal(1.0)


## Sequência % size: PLAINS → DESERT → FOREST → ICE → PLAINS (SC-016).
func test_02_sequencia_completa_ciclando() -> void:
	var sequencia: Array = GameConfig.environment_sequence
	for i in sequencia.size():
		assert_str(progresso.ambiente_atual()).is_equal(String(sequencia[i]))
		progresso.registra_vitoria()
	# 4ª vitória: gelo → planície (novo ciclo).
	assert_str(progresso.ambiente_atual()).is_equal("PLAINS")


## 4 vitórias → ciclos+1, vitorias zeradas, posição 0 (SC-017).
func test_03_quatro_vitorias_novo_ciclo() -> void:
	for i in 4:
		progresso.registra_vitoria()
	assert_int(progresso.ciclos_concluidos).is_equal(1)
	assert_int(progresso.vitorias_ciclo).is_equal(0)
	assert_int(progresso.posicao).is_equal(0)

	# 8 vitórias → 2 ciclos (ciclos só cresce — FR-023).
	for i in 4:
		progresso.registra_vitoria()
	assert_int(progresso.ciclos_concluidos).is_equal(2)
	assert_int(progresso.vitorias_ciclo).is_equal(0)


## Derrota zera posição/vitórias e PRESERVA ciclos concluídos (FR-023).
func test_04_derrota_zera_ciclo_preserva_bonus() -> void:
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()  # 1º ciclo completo
	progresso.registra_vitoria()  # vitória parcial no 2º ciclo (pos=1)
	assert_int(progresso.ciclos_concluidos).is_equal(1)
	assert_int(progresso.vitorias_ciclo).is_equal(1)

	progresso.zerar_ciclo_por_derrota()
	assert_int(progresso.posicao).is_equal(0)
	assert_int(progresso.vitorias_ciclo).is_equal(0)
	assert_int(progresso.ciclos_concluidos).is_equal(1)  # preservado
	assert_str(progresso.ambiente_atual()).is_equal("PLAINS")


## fator_ciclo = 1 + difficulty_cycle_bonus_increment × ciclos (SC-016).
func test_05_fator_ciclo_formula() -> void:
	assert_float(progresso.fator_ciclo()).is_equal(1.0)
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	var incremento: float = GameConfig.difficulty_cycle_bonus_increment
	assert_float(progresso.fator_ciclo()).is_equal_approx(1.0 + incremento, 0.0000001)

	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	progresso.registra_vitoria()
	assert_float(progresso.fator_ciclo()).is_equal_approx(1.0 + incremento * 2.0, 0.0000001)


## A sequência vem da configuração — ambiente inválido não quebra o ciclo
## (fallback PLAINS, environment_cycle.md §1).
func test_06_ambiente_fallback_plains() -> void:
	progresso.posicao = 99
	assert_str(progresso.ambiente_atual()).is_equal("PLAINS")
