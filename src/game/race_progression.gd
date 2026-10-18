class_name RaceProgression
extends RefCounted

## Progresso da sessão da SPEC-009 (FR-019, FR-022, FR-023; data-model §4,
## contracts/environment_cycle.md): posição na `environment_sequence`, vitórias
## do ciclo atual e ciclos concluídos. Não é persistente — fechar o jogo zera
## tudo (garantia 1 do contrato). Não decide estado global: quem chama
## `registra_vitoria`/`zerar_ciclo_por_derrota` é o GameplayManager nos mesmos
## pontos de transição já existentes (garantia 3).

## Índice corrente em `GameConfig.environment_sequence`.
var posicao: int = 0

## Vitórias no ciclo vigente (0..sequence.size()-1).
var vitorias_ciclo: int = 0

## Ciclos completos (só cresce na sessão — FR-023; derrota preserva).
var ciclos_concluidos: int = 0


## Ambiente da próxima corrida. Fallback seguro "PLAINS" para posição
## corrompida (contracts/environment_cycle.md §1 — modo parcialmente inválido
## não quebra a corrida).
func ambiente_atual() -> String:
	var sequencia: Array = GameConfig.environment_sequence
	if sequencia.is_empty():
		return "PLAINS"
	if posicao < 0 or posicao >= sequencia.size():
		return "PLAINS"
	return String(sequencia[posicao])


## Vitória registrada (environment_cycle.md §2): avança a posição % size a
## cada vitória; ao completar o ciclo (`vitorias == size`) → ciclos+1 e
## vitorias zeradas. Ciclo 1 = 1,000 de bônus (SC-015).
func registra_vitoria() -> void:
	var sequencia: Array = GameConfig.environment_sequence
	var tamanho: int = sequencia.size()
	if tamanho <= 0:
		return
	posicao = (posicao + 1) % tamanho
	vitorias_ciclo += 1
	if vitorias_ciclo >= tamanho:
		ciclos_concluidos += 1
		vitorias_ciclo = 0


## Derrota (environment_cycle.md §2): recomeça por PLAINS no próximo menu →
## largada; `ciclos_concluidos` preservado (FR-023 — bônus de escala não é
## perdido).
func zerar_ciclo_por_derrota() -> void:
	posicao = 0
	vitorias_ciclo = 0


## Bônus de escala por ciclo completo (FR-022, SC-016):
## `1 + difficulty_cycle_bonus_increment × ciclos_concluidos`. Aplicado na
## largada, nunca no meio da corrida (FR-006).
func fator_ciclo() -> float:
	return 1.0 + float(GameConfig.difficulty_cycle_bonus_increment) * float(ciclos_concluidos)
