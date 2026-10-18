# Data Model: Sistema de Colisão entre NPCs (SPEC-006)

**Date**: 2026-10-07 | **Branch**: `006-npc-collision-system`

Entidades derivadas de `spec.md` §Key Entities. Nenhuma persistência — tudo vive em memória durante a partida, parametrizado por `GameConfig`. Referências de design: `research.md` (R1–R10).

## 1. Par Candidato a Colisão (NpcCandidatePair)

Unidade de previsão e de reavaliação (FR-001, FR-008). Recalculado sob demanda/periódico, nunca a cada quadro para todos os pares.

| Campo | Tipo | Validação | Origem |
|-------|------|-----------|--------|
| `npc_a`, `npc_b` | `TrafficVehicle` | ambos `state == ACTIVE`, `a != b` | varredura de candidatos (R9) |
| `mesma_trajetoria` | bool | projeções laterais das hitboxes se sobrepõem (FR-006) | geometria |
| `distancia_longitudinal` | float | ≥ 0 (traseiro → dianteiro) | geometria |
| `diferenca_velocidade` | float | `v_traseiro − v_dianteiro`; > `npc_min_relative_speed` para aproximação (FR-002, R1) | velocidades |
| `ttc` | float | `distancia / diferenca`; só válido se `diferenca > 0` | R1 |
| `janela` | float | min(tempo até descarte de a, de b) + `npc_active_area_margin`, limitada por `npc_collision_prediction_horizon` (FR-004) | geometria + estado da pista |
| `potencial` | bool | `ttc <= janela` (FR-003); senão, sem previsão | veredito |

- Chave de cache: par canônico por `instance_id`s ordenados (mesma normalização do cooldown, R5).
- Ordenação determinística de processamento: `(y do candidato mais acima, instance_id)` (R9 — Edge Case "três ou mais NPCs sobrepostos").
- Presença do jogador **não** entra em nenhum campo (FR-009).

## 2. Colisão NPC×NPC (NpcCollisionData)

Evento instantâneo e efêmero; materializado como `Resource` no payload do sinal (FR-041). Um por colisão válida (SC-004/SC-008).

| Campo | Tipo | Validação | Origem |
|-------|------|-----------|--------|
| `causador` | `TrafficVehicle` | ativo; nunca é quem sofre o drift | classificação (R2) |
| `atingido` | `TrafficVehicle` | ativo, `!= causador` | classificação (R2) |
| `tipo` | enum | exatamente um de `LONGITUDINAL`, `LATERAL` (FR-011) | menor penetração (R2) |
| `intensidade` | float | 0.0…1.0, `|v_a − v_b| / collision_intensity_divisor`, clampado (FR-012, mesma convenção da SPEC-005) | cálculo |
| `direcao_drift` | int | −1 esquerda, +1 direita; nunca 0; oposta ao lado do impacto (FR-015, SC-005) | classificação + margem neutra |
| `cadeia_id` | int | id da cadeia a que pertence (própria, se paralela) | cadeia (R4) |
| `profundidade` | int | 1 no impacto raiz; +1 por elo de deslocamento | cadeia (R4) |

Ciclo de vida: criado no quadro do contato → aplica drift/consequências → alimenta o sinal → descartado. **Não criado** sob cooldown, sob bloqueio de cadeia (veículo já processado) ou sem interseção (FR-027, R5/R4).

## 3. Cadeia de Colisão (NpcChainState)

Controle do efeito dominó (FR-024, FR-025). Máximo 1 cadeia ativa por impacto raiz; cadeias paralelas coexistem com ids distintos (Clarificação Q5).

| Campo | Tipo | Validação | Origem |
|-------|------|-----------|--------|
| `id` | int | monotônico crescente, nunca reutilizado durante a partida | contador do sistema |
| `profundidade_atual` | int | 1 ≤ atual ≤ `npc_max_chain_depth` | incremento por elo |
| `profundidade_maxima` | int | = `npc_max_chain_depth` (configurável) | GameConfig (R4) |
| `tempo_restante` | float | inicia em `npc_chain_timeout`; ao chegar a 0 a cadeia expira (FR-025) | decréscimo por quadro |
| `processados` | `Dictionary` (`instance_id → true`) | veículo só pode ser processado 1× por cadeia (0 loops) | registro ao processar |

- **Elo de encadeamento**: um impacto herda `cadeia_id` e soma profundidade **apenas** quando o atingido, com drift ainda ativo, atinge um terceiro (FR-024). Colisões paralelas iniciam cadeia própria (Clarificação Q5, US5-CA8).
- Ciclo de vida: criado no primeiro impacto → expira por tempo ou por profundidade máxima → descartado (nenhum elo adicional).

## 4. Estado de Drift do NPC (NpcDriftState)

Um por `TrafficVehicle`, máximo 1 ativo (FR-014; Clarificação Q4 — novo impacto **substitui** o atual). Nunca altera velocidade (FR-017, SC-014).

| Campo | Tipo | Notas |
|-------|------|-------|
| `fase` | enum `NORMAL, IMPACTO, DRIFT, RECUPERACAO` | FR-021; transições somente nesta ordem, sem outros estados |
| `direcao` | int (−1/+1) | herdada do impacto; pode ser invertida pela borda (FR-019) |
| `forca` | float | `lerpf(npc_drift_force_min, max, intensidade)` |
| `duracao` | float | `lerpf(npc_drift_duration_min, max, intensidade)` |
| `tempo_decorrido` | float | zera na entrada; drift é temporário (FR-023) |
| `deslocamento_acumulado` | float | ≤ `npc_displacement_limit` (FR-020) |

Transições: `NORMAL --(colisão válida)--> IMPACTO --(instante)--> DRIFT --(duração)--> RECUPERACAO --(taxa npc_drift_recovery_rate)--> NORMAL`. Encerrada a recuperação o NPC **permanece na posição lateral alcançada** — sem retorno à origem (FR-022, Clarificação Q1); sujeito só aos limites da pista e ao agrupamento lateral do SPEC-004 (trajetória atual).

Aplicação por quadro: deslocamento em `position.x` com clamp pelos limites **na altura do veículo** (`Road.get_boundaries_for_player_y`), consultados por quadro — nunca largura fixa (FR-018, FR-040).

## 5. Cooldown por Par

Bloqueio temporário entre dois veículos específicos (FR-026, R5).

| Campo | Tipo | Validação |
|-------|------|-----------|
| chave | `String` `"idA:idB"` com `idA < idB` (par canônico, ordem-insensível) | identidade única do par |
| `tempo_restante` | float | em countdown; enquanto > 0: **nenhum** evento nem consequência (FR-027) |

- Rearmamento: exige expiração do tempo **e** separação dos veículos (não mais sobrepostos) — Edge Case "cooldown expira com os dois ainda sobrepostos".
- Isolamento: A↔B bloqueado não afeta B↔C (SC-009). O mesmo par separando-se e voltando a se tocar durante o cooldown não gera evento (SC-009).

## 6. Configuração de Colisão NPC×NPC (GameConfig, FR-044)

Todos exportados do autoload `GameConfig`; nenhum valor fixo na lógica (SC-017). Valores padrão e papéis: ver `research.md` §Valores de configuração.

| Grupo | Parâmetros |
|-------|-----------|
| Cooldown | `npc_collision_cooldown` |
| Drift | `npc_drift_force_min/max`, `npc_drift_duration_min/max`, `npc_drift_recovery_rate` |
| Direção e borda | `npc_relative_position_threshold`, `npc_border_margin` |
| Cadeia | `npc_max_chain_depth`, `npc_chain_timeout` |
| Deslocamento | `npc_displacement_limit` |
| Previsão e janela | `npc_collision_prediction_horizon`, `npc_min_relative_speed`, `npc_active_area_margin` |
| Spawn | `npc_spawn_safety_distance` |
| Teto de ativos | `npc_max_active` (projeção somente leitura do teto por dificuldade do SPEC-004 FR-064 — sem parâmetro armazenado) |
| Reavaliação | `npc_reevaluation_interval`, `npc_player_speed_change_threshold` |

## Relacionamentos

- `NpcCollisionSystem` 1—n `TrafficVehicle` (avalia pares entre os ativos; teto `npc_max_active`, 5 em Gelo).
- `NpcCandidatePair` 2—1 `TrafficVehicle`; cache de curta duração, invalidado por eventos (spawn, reciclagem, deslocamento, mudança de pista) e pelo periódico (R8).
- `NpcDriftState` 1—1 `TrafficVehicle` (máx. 1 por veículo); posse do veículo, sobrevive à reciclagem só até `deactivate()`.
- `NpcCollisionData` referencia `causador` + `atingido` + cadeia; efêmero, não armazenado.
- `NpcChainState` n—1 `NpcCollisionData` (vários impactos por cadeia); múltiplas cadeias paralelas coexistem.
- Cooldown: mapa `par canônico → tempo_restante`, escopo exclusivo NPC↔NPC (o SPEC-005 mantém o seu, por `npc_id`, jogador↔NPC).
