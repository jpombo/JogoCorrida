class_name TrackManager
extends Node

## Progressão da corrida em distância (SPEC-008, FR-005…FR-008, research R1).
## A distância é integrada pela velocidade de AVANÇO do jogador — nunca pela
## rolagem da estrada (FR-007, reciclagem de segmentos é independente) nem
## pela posição vertical do sprite (FR-007). Mudança de faixa não conta
## (Clarificação de faixa: "não cresce") — só `velocidade_avanco` entra aqui.

## Emitido quando a distância varia de fato — `0 ≤ percorrida ≤ total` — e no
## reset (para o indicador de UI nascer zerado).
signal progress_changed(percorrida: float, total: float, percentual: float)

## Distância total da corrida em km (guard: `> 0` define o motivo de progresso).
var total: float = 0.0

## Distância percorrida em km — monotônica não-crescente, limitada ao total.
var percorrida: float = 0.0

## Distância restante em km (derivada: `total − percorrida`, nunca negativa).
var restante: float = 0.0

## Fração [0, 1] da corrida; `total ≤ 0` ⇒ 1.0 (data-model §2).
var percentual: float = 1.0

## Só vira true na transição de vitória, chamada pelo GameplayManager (R9).
var concluido: bool = false


## Recebe a configuração vigente da corrida. Não emite — quem nasce a corrida
## é o `reset()` (data-model §2, research R1).
func setup(total_km: float, _player_y: float = 0.0) -> void:
	total = maxf(total_km, 0.0)


## Rearma a corrida: percorrida zerada, concluído falso, derivados recalculados
## e sinal emitido (UI nasce em 0,0 km) — data-model §2.
func reset() -> void:
	percorrida = 0.0
	concluido = false
	_recalcular()
	progress_changed.emit(percorrida, total, percentual)


## Integra a distância por quadro: `percorrida + velocidade × track_units_to_km
## × delta`, com teto no total por construção (`minf` — SC-003/SC-004).
## Guarda de conclusão por comparação EXATA (percorrida só recebe `minf(…,
## total)`, logo só atinge o total por igualdade exata): uma tolerância
## aproximada engoliria avanços menores que ~total×1e-5 perto da chegada e a
## corrida nunca completaria. Emitir apenas em variação real; chamado só no
## ramo PLAYING (research R9).
func update(delta: float, velocidade_avanco: float) -> void:
	if total <= 0.0:
		return
	if delta <= 0.0 or velocidade_avanco <= 0.0:
		return
	if percorrida >= total:
		return
	percorrida = minf(
		percorrida + velocidade_avanco * GameConfig.track_units_to_km * delta,
		total
	)
	_recalcular()
	progress_changed.emit(percorrida, total, percentual)


## Chamado pelo GameplayManager na vitória (cruzamento completo + combustível
## positivo — FR-013, research R9); trava a reavaliação de fim de corrida.
func marcar_concluido() -> void:
	concluido = true


func esta_concluido() -> bool:
	return concluido


func get_percorrida() -> float:
	return percorrida


func get_restante() -> float:
	return restante


func get_percentual() -> float:
	return percentual


func get_total() -> float:
	return total


func _recalcular() -> void:
	restante = maxf(total - percorrida, 0.0)
	percentual = percorrida / total if total > 0.0 else 1.0
