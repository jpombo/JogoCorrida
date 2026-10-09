class_name NpcChainState
extends RefCounted

## Cadeia de colisão ativa do efeito dominó (SPEC-006, FR-024/FR-025,
## data-model §3, research R4).
##
## Uma cadeia nasce no primeiro impacto raiz e só avança quando o CAUSADOR de
## um novo impacto é um ex-atingido com drift ainda ativo — o chamador
## decide o elo; este objeto responde PODE avançar (profundidade) e o veículo
## já foi processado (0 loops). Cadeias paralelas convivem com ids distintos
## (Clarificação Q5): o tempo sozinho nunca transfere cadeia.
##
## Tudo configurável em GameConfig (FR-044): profundidade máxima e timeout
## são lidos na CRIAÇÃO da cadeia; nenhum número mágico aqui.

## Id monotônico crescente, nunca reutilizado durante a partida — contador
## do NpcCollisionSystem (data-model §3).
var id: int

## Profundidade do elo corrente (1 no impacto raiz), ≤ profundidade_maxima.
var profundidade_atual: int = 1

## Teto da cadeia (= GameConfig.npc_max_chain_depth no momento da criação).
var profundidade_maxima: int

## Segundos até a cadeia expirar (= GameConfig.npc_chain_timeout na criação);
## ao chegar a 0 a cadeia é descartada e nenhum elo adicional é processado.
var tempo_restante: float

## instance_id → true dos veículos já processados por ESTA cadeia: um
## veículo não pode ser processado duas vezes (FR-025, SC-008 = 0 loops).
var processados: Dictionary = {}


func _init(p_id: int) -> void:
	id = p_id
	profundidade_maxima = GameConfig.npc_max_chain_depth
	tempo_restante = GameConfig.npc_chain_timeout


## Registra um participante do impacto processado (ambos os envolvidos).
func registrar(instance_id: int) -> void:
	processados[instance_id] = true


func ja_processado(instance_id: int) -> bool:
	return processados.has(instance_id)


## O próximo elo caberia nesta cadeia? (FR-025: teto de profundidade).
func pode_avancar() -> bool:
	return profundidade_atual < profundidade_maxima


func expirada() -> bool:
	return tempo_restante <= 0.0


## Decrementa o cronômetro por quadro (chamado pelo sistema).
func avancar(delta: float) -> void:
	tempo_restante = maxf(tempo_restante - delta, 0.0)
