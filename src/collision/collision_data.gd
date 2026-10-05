class_name CollisionData
extends Resource

## Payload do evento de colisão (SPEC-005, contracts/collision_event.md).
## Efêmero: criado no quadro da detecção e descartado após a emissão.

enum CollisionType {
	PLAYER_HITS_NPC_REAR,  ## 1-1: jogador atinge a traseira do NPC
	LATERAL,               ## 1-2: contato lateral
	NPC_HITS_PLAYER_REAR,  ## 1-3: NPC atinge a traseira do jogador
}

var player: Node2D = null
var npc: TrafficVehicle = null
var tipo: int = CollisionType.PLAYER_HITS_NPC_REAR
var velocidade_impacto: float = 0.0
var intensidade: float = 0.0

## Direção do drift: -1 esquerda, +1 direita (nunca 0 — FR-004/FR-005).
var direcao_drift: int = -1
