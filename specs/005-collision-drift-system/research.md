# Research: Sistema de Colisão e Drift (SPEC-005)

**Date**: 2026-10-05 | **Branch**: `005-collision-drift-system`

Nenhum item do Technical Context ficou como NEEDS CLARIFICATION — Godot/GDScript e GdUnit4 já são o stack consolidado das SPECs 001–004. As decisões abaixo resolvem os pontos de design em aberto.

## R1 — Detecção: interseção de Rect2 em código, sem nós de física

- **Decision**: Detectar a colisão em GDScript puro, calculando `Rect2` da hitbox do jogador e de cada NPC ativo por quadro e testando `intersects`. Não usar `Area2D`/`CollisionShape2D` nem o servidor de física.
- **Rationale**: (1) FR-006–FR-008 exigem hitboxes configuráveis independentes de sprite/scene — `Rect2` derivado de configuração satisfaz direto; (2) o SPEC-004 já expõe `TrafficVehicle.get_occupied_area() -> Rect2`, contrato ratificado pela constituição v2.0.0 §Trânsito — a detecção consome esse padrão; (3) o jogo roda sem `physics_server` ativo para gameplay (scroll é manual), e adicionar nós de física criaria acoplamento com cenas e ordem de callbacks — contra a simplicidade (constituição II).
- **Alternatives considered**: `Area2D` com sinais `area_entered` (rejeitado: acopla a árvore de cenas, dificulta teste unitário headless e hitbox por configuração); física `move_and_collide` (rejeitado: modelo arcade translacional não precisa de solver).

## R2 — Classificação em 3 tipos pela posição relativa dos centros

- **Decision**: Classificar por comparação dos centros das hitboxes no momento da interseção: diferença vertical dominante + sinal da velocidade relativa distingue "jogador atinge traseira do NPC" de "NPC atinge traseira do jogador"; diferença horizontal dominante → "colisão lateral". Margem neutra configurável (FR-005) decide empates horizontais de forma determinística: lado com mais espaço trafegável; empate absoluto → esquerda (Assumptions).
- **Rationale**: FR-003 proíbe direção fixa predefinida; usar o vetor entre centros é o critério mais simples, determinístico e testável. A dominância entre eixos é decidida por limiares configuráveis derivados das dimensões das hitboxes.
- **Alternatives considered**: Vetor de movimento relativo (rejeitado: no scroll top-down, o movimento aparente é quase todo longitudinal e esconderia contatos laterais — violaria US2); overlap de profundidade por eixo (mantido como desempate interno, não como critério primário).

## R3 — Máquina de estados do jogador e controle reduzido

- **Decision**: `DriftState` implementa FR-015 (`normal → impacto → drift → recuperação → normal`) como enum + transições por tempo/intensidade. Durante `drift`/`recuperação`, o `VehicleController` aplica um multiplicador de controle (fator configurável, padrão 40%) sobre a aceleração lateral, interpolado de volta a 100% na `recuperação`. O deslocamento do impacto é uma velocidade lateral extra que decai com o tempo.
- **Rationale**: Gancho mínimo e aditivo no `VehicleController` (um multiplicador, default 1.0) preserva FR-034 — sem colisão, nada muda. Interpolação linear da influência do impacto satisfaz FR-014 com taxa configurável.
- **Alternatives considered**: Desativar input durante o drift (rejeitado: FR-013 proíbe controle zero); física de impulso com atrito (rejeitado: complexidade sem ganho arcade).

## R4 — Ultrapassagem do NPC (tipo 1-3)

- **Decision**: `NpcOvertakeState` aplica ao `TrafficVehicle` um deslocamento lateral temporário (magnitude/duração configuráveis, FR-019) para o lado oposto ao drift do jogador, com clamp pelos limites da estrada na altura atual do NPC (FR-020) e espera quando não há espaço (Edge Case). Velocidade da categoria nunca é tocada (FR-017, FR-021).
- **Rationale**: Reusa o padrão de deslocamento já existente em `TrafficVehicle.update_scroll` (clamp por `bounds`), mantendo a reciclagem e o movimento aparente intactos; o deslocamento é um offset de posição, não uma mudança de estado do trânsito (FR-033).
- **Alternatives considered**: Acelerar o NPC temporariamente (rejeitado: viola FR-017 e o Out of Scope); teleportar para faixa vizinha (rejeitado: quebra a sensação arcade gradual).

## R5 — Cooldown por par jogador↔NPC

- **Decision**: Dicionário `{instance_id_do_npc: tempo_restante}` no `CollisionSystem`, decrementado por quadro; colisão só é válida se o par não estiver em cooldown **e** houver transição não-sobreposto→sobreposto. Nova colisão após cooldown exige separação e novo contato (US5-CA3, Assumptions).
- **Rationale**: FR-026/FR-027 exigem cooldown por par; a regra de "rearmer somente após separação" resolve o edge case de sobreposição persistente de forma determinística e simples. `instance_id` é único por veículo do pool e estável enquanto ativo.
- **Alternatives considered**: Cooldown global (rejeitado: viola FR-027 — dois NPCs distintos no mesmo instante devem gerar duas colisões, Edge Case "Múltiplos NPCs"); rearmer por tempo apenas (rejeitado: penalização repetida sem novo impacto real).

## R6 — Evento de colisão desacoplado

- **Decision**: Sinal `collision_occurred(data: CollisionData)` emitido pelo `CollisionSystem`; `CollisionData` é um `Resource` com os 6 campos mínimos de FR-029 (jogador, NPC, tipo, velocidade de impacto, direção do drift, intensidade). Registrado em `contracts/collision_event.md`. Colisões sob cooldown não emitem nada (FR-028).
- **Rationale**: Constituição III exige comunicação por sinais/eventos; FR-030 proíbe efeitos colaterais — o sinal sem ouvintes obrigatórios é a implementação canônica Godot de evento desacoplado, pronto para o spec de combustível.
- **Alternatives considered**: Barramento global de eventos em autoload (rejeitado: indireção prematura — um único emissor; quando specs futuras precisarem, o sinal pode ser retransmitido).

## R7 — Limites da estrada por altura

- **Decision**: Todos os clamps (drift do jogador e deslocamento do NPC) consultam os limites vigentes da estrada na altura do veículo no quadro corrente (mesma fonte já usada por `VehicleController.update_boundaries` e pelos `bounds` de `TrafficVehicle.update_scroll`), sem cache de largura fixa.
- **Rationale**: FR-022/FR-023 e os edge cases de transição 2↔4 vias exigem consulta dinâmica; a infraestrutura já existe desde a SPEC-002 — custo zero e zero divergência de comportamento.
- **Alternatives considered**: Largura fixa da pista (rejeitado: contradiz FR-022 explicitamente).

## R8 — Intensidade do impacto

- **Decision**: Intensidade = velocidade relativa longitudinal (|v_jogador − v_npc|, em px/s internos; conversão km/h↔unidades internas conforme convenção do SPEC-004) normalizada por um divisor configurável e clampada em [0,1]. Perda de velocidade, força e duração do drift interpolam entre os pares mín/máx configuráveis por essa intensidade (FR-024, FR-025). Fórmula linear como padrão, substituível pois os parâmetros são configuração.
- **Rationale**: Atende "proporcional" com a fórmula mais simples e testável; todos os coeficientes em `GameConfig` (SC-012).
- **Alternatives considered**: Curva quadrática (rejeitado como padrão: dificulta calibração; pode ser revisitada no tuning sem mudar o modelo).
