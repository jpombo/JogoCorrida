class_name NpcCollisionData
extends Resource

## Payload do evento de colisão NPC×NPC (SPEC-006, FR-041,
## contracts/npc_collision_event.md). Efêmero: criado no quadro da detecção e
## descartado após a emissão — nenhum sistema o armazena.

enum Tipo {
	LONGITUDINAL,  ## um NPC alcança a traseira do outro (FR-011)
	LATERAL,       ## contato predominantemente lateral (FR-011)
}

## Quem provocou o impacto: nunca sofre drift automático nem perde velocidade
## (FR-016). Em lateral, é quem fechou a trajetória do outro (FR-013).
var causador: TrafficVehicle = null

## Quem recebe o drift — um único drift ativo por veículo; novo impacto
## substitui o em curso (FR-014, Clarificação Q4).
var atingido: TrafficVehicle = null

## Exatamente um dos dois tipos, pela geometria do contato (FR-011).
var tipo: int = Tipo.LONGITUDINAL

## 0.0…1.0 — velocidade relativa no contato normalizada (FR-012).
var intensidade: float = 0.0

## −1 esquerda, +1 direita (nunca 0): direção EFETIVAMENTE aplicada após o
## fallback de borda/transferência ao causador (FR-015, FR-019).
var direcao_drift: int = 0

## Cadeia à qual o impacto pertence — cadeias paralelas têm ids distintos
## (FR-024, Clarificação Q5).
var cadeia_id: int = 0

## Profundidade atual da cadeia (1 no impacto raiz) — FR-025.
var profundidade: int = 0
