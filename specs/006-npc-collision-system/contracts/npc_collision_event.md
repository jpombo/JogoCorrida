# Contract: Evento de Colisão NPC×NPC (FR-041)

**Feature**: SPEC-006 | **Versão**: 1.0 (2026-10-07)

Contrato público do sistema de colisão NPC×NPC para sistemas futuros (efeitos visuais/sonoros, partículas, pontuação, telemetria, dificuldade). O sistema **não** modifica nenhum outro sistema — apenas emite o evento. Consumidores observam; nenhum consumidor é obrigatório nesta versão (FR-041, US6-CA5).

## Sinal

```
NpcCollisionSystem.npc_collision_occurred(data: NpcCollisionData) -> void
```

- Emitido **exatamente uma vez por colisão válida**, no quadro do contato.
- **Não emitido** quando a colisão é bloqueada pelo cooldown do par (FR-027), pela regra de cadeia (veículo já processado / profundidade máxima) ou quando não há interseção de áreas (SC-008, SC-009).
- Colisão com o jogador **não passa por aqui** — é o `CollisionSystem.collision_occurred` da SPEC-005 que a emite, com exatamente um evento (FR-037/FR-038, SC-015).

## Payload: NpcCollisionData (Resource)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `causador` | TrafficVehicle | veículo que provocou o impacto (nunca sofre drift automático — FR-016) |
| `atingido` | TrafficVehicle | veículo que recebe o drift (FR-014) |
| `tipo` | int (enum) | `LONGITUDINAL` ou `LATERAL` — exatamente um (FR-011) |
| `intensidade` | float | 0.0…1.0, velocidade relativa no contato normalizada (FR-012; mesma convenção da SPEC-005) |
| `direcao_drift` | int | −1 esquerda, +1 direita (nunca 0); direção **efetivamente aplicada** após o fallback de borda (FR-015/FR-019) |
| `cadeia_id` | int | identificador da cadeia a que pertence; cadeias paralelas têm ids distintos (FR-024) |
| `profundidade` | int | profundidade atual da cadeia (1 no impacto raiz) |

## Garantias

- A velocidade dos dois envolvidos é **idêntica** antes, durante e depois do impacto — o evento não autoriza alteração de velocidade (FR-017, SC-014).
- O evento reflete o instante do contato, não estado posterior.
- Um mesmo par em cooldown não gera novo evento até expirar + separação (FR-026).
- Registro em barramento global é responsabilidade de spec futura, se necessário.

## Consumo previsto (exemplos, fora de escopo aqui)

- Feedback visual/sonoro de batida entre NPCs.
- Pontuação por "quase acidentes" / telemetria.
- Dificuldade (SPEC-008) observando a frequência de colisões.
