class_name FuelSystem
extends Node

## Sistema de combustível (SPEC-007) — componente próprio (constitution §III).
## Mantém a quantidade atual do tanque da partida, calcula o consumo pelo tempo
## decorrido e pela velocidade (FR-004…FR-010), aplica penalidades de colisão
## por ambiente (FR-011…FR-017), detecta combustível baixo e esgotado e emite
## os três eventos da spec (FR-018…FR-024). Não toca em movimento, colisão,
## estados ou física (FR-021/FR-029/FR-030) — a UI apenas observa (FR-025).

## Emitido quando a quantidade atual varia de fato (consumo ou penalidade),
## sempre com `0 <= atual <= capacidade` — FR-024, contracts/fuel_events.md §1.
signal fuel_changed(atual: float, capacidade: float)

## Emitido UMA vez na travessia do limite de combustível baixo — FR-023.
signal fuel_low()

## Emitido UMA vez por esgotamento, qualquer que seja a origem — FR-018/FR-019.
signal fuel_depleted()

## Estado do tanque (data-model.md §1): clamped em toda escrita.
var _atual: float = 0.0
var _capacidade: float = 0.0

## Capacidade derivada da corrida (SPEC-008, Clarificação de capacidade, R3).
## -1.0 = sem override (o reset usa GameConfig.fuel_capacity); ≥ 0 substitui
## a capacidade no próximo reset() — aditivo, sem quebrar as suítes SPEC-007.
var _capacidade_derivada: float = -1.0

## Latches rearmedes somente em `reset()` (research R5) — FR-019, FR-023.
var _baixo_sinalizado: bool = false
var _esgotado_emitido: bool = false

## Fator de velocidade da corrida (SPEC-009, R3): `_taxa_consumo` normaliza
## pelo teto EFETIVO (max_speed × fator) e multiplica a taxa pelo mesmo
## fator — consumo por KM constante em todos os modos (SC-008), mantendo a
## capacidade derivada da SPEC-008 válida sem novo dimensionamento.
## Default 1,0 = modelo SPEC-007 intacto (R12); injetado por corrida.
## `reset()` NÃO o toca — a virada READY → PLAYING re-executa o reset e
## apagaria a injeção da largada.
var fator_velocidade: float = 1.0

## Fator do modo aplicado à penalidade de colisão (SPEC-009, R7/SC-007):
## `on_player_collision` aplica collision_fuel_penalty[ambiente] × fator.
## Default 1,0 = SPEC-007 intacto (R12); mesmo ciclo de vida de
## `fator_velocidade` (reset preserva).
var fator_penalidade_colisao: float = 1.0


## Define (ou limpa, com negativo) a capacidade da corrida — SPEC-008,
## FR-018/FR-019. Chamado pelo GameplayManager ANTES do reset() na largada
## (research R3); o comportamento SPEC-007 sem chamada permanece intacto.
func definir_capacidade_derivada(cap: float) -> void:
	if cap < 0.0:
		_capacidade_derivada = -1.0
	else:
		_capacidade_derivada = maxf(cap, 0.0)


## Restaura unidades do tanque (coleta de galão — SPEC-008, FR-024/FR-025,
## research R4). Tanque cheio ⇒ no-op silencioso (sem variação); nunca rearma
## nem dispara `fuel_depleted` (Clarificação "sem rearme"); a autoridade de
## quantidade/capacidade/eventos permanece aqui (FR-033).
func restaurar(valor: float) -> void:
	if _capacidade <= 0.0:
		return
	var incremento: float = maxf(valor, 0.0)
	if incremento <= 0.0:
		return
	_escrever(clampf(_atual + incremento, 0.0, _capacidade))


## Rearma os latches e define a quantidade inicial (sentinela -1 ⇒ capacidade;
## qualquer outro valor, clamp [0, capacidade]) — FR-002/FR-003, data-model §1.
## Chamado exclusivamente na transição READY → PLAYING (research R4).
func reset() -> void:
	_baixo_sinalizado = false
	_esgotado_emitido = false
	if _capacidade_derivada >= 0.0:
		_capacidade = _capacidade_derivada
	else:
		_capacidade = maxf(GameConfig.fuel_capacity, 0.0)
	var inicial: float = GameConfig.fuel_initial_amount
	if is_equal_approx(inicial, -1.0):
		_atual = _capacidade
	else:
		_atual = clampf(inicial, 0.0, _capacidade)
	fuel_changed.emit(_atual, _capacidade)
	_avaliar_limiar()


## Consome `taxa(delta, velocidade) * delta` com clamp [0, capacidade] —
## independente da taxa de quadros (FR-005, SC-003). No-op de consumo com o
## tanque esgotado (FR-020). Chamado apenas no ramo PLAYING (research R4).
func update(delta: float, velocidade: float) -> void:
	if _atual <= 0.0:
		_avaliar_limiar()
		return
	var taxa: float = _taxa_consumo(velocidade)
	_escrever(clampf(_atual - taxa * delta, 0.0, _capacidade))
	_avaliar_limiar()


## Desconta `collision_fuel_penalty[ambiente] × fator_penalidade_colisao`
## lido NO MOMENTO do evento, com clamp a zero — FR-011/FR-016/FR-017.
## SPEC-009 / R7 (SC-007): o fator do modo é aplicado AQUI, no único ponto
## de leitura da penalidade — 1 evento = 1 desconto, sem deduplicação
## própria (FR-013, R2). Penalidade base 0 × fator = 0 (nunca negativa).
func on_player_collision(_data = null) -> void:
	if _atual <= 0.0:
		return
	var ambiente: String = GameConfig.current_environment_id
	var penalidade: float = (
		float(GameConfig.collision_fuel_penalty.get(ambiente, 0.0))
		* fator_penalidade_colisao
	)
	if penalidade <= 0.0:
		return
	_escrever(clampf(_atual - penalidade, 0.0, _capacidade))
	_avaliar_limiar()


## Estado persistente de combustível baixo, derivado do valor atual — FR-022,
## data-model §4. Guarda de divisão para capacidade zero (borda de config).
func esta_baixo() -> bool:
	if _capacidade <= 0.0:
		return false
	return _atual <= GameConfig.fuel_low_threshold * _capacidade


func get_atual() -> float:
	return _atual


func get_capacidade() -> float:
	return _capacidade


## Modelo linear de consumo (research R1): repouso usa o consumo em repouso;
## em movimento, `min + normalização × fator` com teto no máximo — FR-006…FR-009.
## SPEC-009 / R3: a normalização usa o teto EFETIVO (max_speed × fator) e a
## taxa final é multiplicada pelo fator — consumo por km constante (SC-008),
## com o mesmo clamp [min, max] do modelo já sobre a taxa escalada.
func _taxa_consumo(velocidade: float) -> float:
	if velocidade <= 0.0:
		return GameConfig.fuel_consumption_idle
	var fator: float = maxf(fator_velocidade, 0.001)
	var normalizada: float = clampf(velocidade / (GameConfig.max_speed * fator), 0.0, 1.0)
	var taxa: float = (GameConfig.fuel_consumption_min \
		+ normalizada * GameConfig.fuel_consumption_speed_factor) * fator
	return clampf(
		taxa,
		GameConfig.fuel_consumption_min * fator,
		GameConfig.fuel_consumption_max * fator
	)


## Toda escrita passa por aqui: emite `fuel_changed` apenas em variação real e
## arma o latch de esgotamento na primeira atingida de zero — FR-010/FR-018…FR-020.
func _escrever(novo: float) -> void:
	var mudou: bool = not is_equal_approx(novo, _atual)
	_atual = novo
	if mudou:
		fuel_changed.emit(_atual, _capacidade)
	if _atual <= 0.0 and not _esgotado_emitido:
		_esgotado_emitido = true
		fuel_depleted.emit()


## Avalia a travessia do limiar após cada operação válida (consumo, penalidade
## ou o valor inicial no `reset()`) — FR-022/FR-023, research R5, bordas 10/15.
func _avaliar_limiar() -> void:
	if _capacidade <= 0.0:
		return
	if esta_baixo() and not _baixo_sinalizado:
		_baixo_sinalizado = true
		fuel_low.emit()
