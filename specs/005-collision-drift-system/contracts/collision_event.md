# Contract: Evento de Colisão (FR-029, FR-030)

**Feature**: SPEC-005 | **Versão**: 1.0

Contrato público do sistema de colisão para sistemas futuros (combustível, feedback visual/sonoro, dificuldade). O sistema de colisão **não** modifica nenhum outro sistema — apenas emite o evento. Consumidores observam; nenhum consumidor é obrigatório.

## Sinal

```
CollisionSystem.collision_occurred(data: CollisionData) -> void
```

- Emitido **exatamente uma vez por colisão válida**, no quadro da detecção, após a classificação.
- Colisões ignoradas por cooldown **não emitem** o evento (FR-028, US6-CA3).
- Colisão entre NPCs ou com decoração **não existe** (FR-031).

## Payload: CollisionData (Resource)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `player` | Node2D | veículo do jogador |
| `npc` | TrafficVehicle | veículo NPC envolvido |
| `tipo` | int (enum) | `PLAYER_HITS_NPC_REAR` (1-1), `LATERAL` (1-2), `NPC_HITS_PLAYER_REAR` (1-3) |
| `velocidade_impacto` | float | velocidade relativa no contato, unidades internas/s |
| `intensidade` | float | 0.0…1.0, derivada da velocidade relativa (R8) |
| `direcao_drift` | int | −1 esquerda, +1 direita (nunca 0) |

## Garantias

- O evento distingue os três tipos sem ambiguidade (US6-CA2).
- `velocidade_impacto`/`intensidade` refletem o instante do contato, não estado posterior.
- Registro no barramento global é responsabilidade de spec futura, se necessário (R6).

## Consumo previsto (exemplos, fora de escopo aqui)

- Spec de combustível: reduzir combustível proporcionalmente à `intensidade`.
- Feedback: som/vibração conforme `tipo` e `intensidade`.
