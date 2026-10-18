# Data Model: Sistema de Colisão e Drift (SPEC-005)

**Date**: 2026-10-05 | **Branch**: `005-collision-drift-system`

Entidades derivadas de `spec.md` §Key Entities. Nenhuma persistência — tudo vive em memória durante a partida, parametrizado por `GameConfig`.

## 1. Colisão (CollisionData)

Evento instantâneo e efêmero; materializado como `Resource` no payload do evento de colisão (FR-029).

| Campo | Tipo | Validação | Origem |
|-------|------|-----------|--------|
| `player` | `Node2D` (PlayerVehicle) | não nulo | detecção |
| `npc` | `TrafficVehicle` | não nulo, `state == ACTIVE` | detecção |
| `tipo` | enum | exatamente um de `PLAYER_HITS_NPC_REAR` (1-1), `LATERAL` (1-2), `NPC_HITS_PLAYER_REAR` (1-3) (FR-002) | classificação (R2) |
| `velocidade_impacto` | float | ≥ 0; velocidade relativa no contato (FR-024) | cálculo |
| `intensidade` | float | 0.0…1.0 (R8) | cálculo |
| `direcao_drift` | int | −1 esquerda, +1 direita; nunca 0 após FR-005 | classificação |

Ciclo de vida: criado no quadro da detecção → alimenta consequências e o sinal → descartado. Não emitido sob cooldown (FR-028).

## 2. Estado de Drift do Jogador (DriftState)

Pertence exclusivamente ao jogador. Um único ativo por vez; nova colisão válida substitui o anterior (Edge Case).

| Campo | Tipo | Notas |
|-------|------|-------|
| `fase` | enum `NORMAL, IMPACTO, DRIFT, RECUPERACAO` | FR-015, transições somente nesta ordem |
| `direcao` | int (−1/+1) | herdada da colisão |
| `forca_restante` | float | decai com o tempo; deslocamento lateral extra |
| `tempo_decorrido` | float | zera na entrada; drift tem duração limitada (FR-014) |
| `fator_controle` | float | 0 < f ≤ 1; padrão de início 0.4; → 1.0 na recuperação (FR-013, SC-004) |

Transições: `NORMAL --(colisão válida)--> IMPACTO --(instante)--> DRIFT --(duração)--> RECUPERACAO --(fator=1.0)--> NORMAL`. Sem outros estados nem transições de retorno (FR-015).

## 3. Hitbox

Área física retangular por veículo, independente do sprite (FR-006), relativa ao centro.

| Campo | Tipo | Notas |
|-------|------|-------|
| `dimensoes` | Vector2 (largura, altura) | jogador: configuração própria; NPC: por categoria (FR-007) |
| derivação | configuração → `Rect2(centro − dim/2, dim)` | jogador segue o mesmo padrão de `TrafficVehicle.get_occupied_area()` |

Valores iniciais derivados da área visual atual com margens laterais reduzidas (Assumptions); alterar sprite não altera hitbox (SC-009). Recalibração 2026-10-10 (reajuste de arte — conteúdo normalizado no canvas): jogador 22×44, passeio 22×38, utilitário 22×38, esporte 22×46, caminhão 30×64 (sprite não reajustado); derivação documentada no comentário de `GameConfig.player_hitbox_size`/`NPC_HITBOX_SIZES`.

## 4. Deslocamento de Ultrapassagem do NPC (NpcOvertakeState)

Somente na colisão 1-3. Nunca toca a velocidade da categoria (FR-017, FR-021). Duas fases (ajuste 6): ida até a magnitude e retorno à faixa de origem.

| Campo | Tipo | Notas |
|-------|------|-------|
| `fase` | enum (inativa/ida/retorno) | a ida termina ao atingir a magnitude ou o limite da pista; o retorno termina ao reocupar a faixa de origem (FR-021) |
| `direcao` | int (−1/+1) | oposta ao drift do jogador (FR-018) |
| `magnitude` | float | alvo lateral total da ida, configurável (FR-019) |
| `duracao` / `duracao_retorno` | float | durações da ida e do retorno, configuráveis (FR-019); ao terminar o retorno, estado inativo sem drift permanente (FR-021) |
| `x_origem` | float | x da faixa ocupada antes da colisão; preservado se nova colisão ocorrer durante o deslocamento |
| clamp | limites da estrada na altura do NPC, por quadro | FR-020; ida e retorno são clampados; sem espaço a ida para no limite e conclui quando houver espaço (Edge Case) |

## 5. Configuração de Colisão e Drift (GameConfig, FR-035)

Todos os parâmetros a seguir são constantes exportadas do autoload `GameConfig`; nenhum valor fixo na lógica (SC-012).

| Grupo | Parâmetros (nomes de referência) |
|-------|----------------------------------|
| Perda de velocidade | `collision_speed_loss_min`, `collision_speed_loss_max` |
| Bloqueio da aceleração | `collision_accel_lockout_time` (janela em que `accelerate` é desconsiderada pós-colisão — FR-036) |
| Drift | `drift_force_min/max`, `drift_duration_min/max`, `drift_control_factor` (0.4), `drift_recovery_rate` |
| Cooldown | `collision_cooldown_time` |
| Classificação | `collision_neutral_margin` |
| Ultrapassagem NPC | `npc_overtake_magnitude`, `npc_overtake_duration`, `npc_overtake_return_duration` |
| Intensidade | `collision_intensity_divisor` |
| Hitboxes | `player_hitbox_size`, `npc_hitbox_size` por categoria (caminhão/esporte/passeio/utilitário) |

## Relacionamentos

- `CollisionSystem` 1—n `TrafficVehicle` (avalia por quadro; n ativos).
- `Cooldown`: mapa `npc_instance_id → tempo_restante` (R5), escopo do par jogador↔NPC (FR-027).
- `DriftState` n—1 `PlayerVehicle`; `NpcOvertakeState` n—1 `TrafficVehicle` (máx. 1 por veículo).
- `CollisionData` referencia par jogador↔NPC; não é armazenado.
