# Implementation Plan: Sistema de Colisão entre NPCs

**Branch**: `006-npc-collision-system` | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-npc-collision-system/spec.md`

## Summary

Implementar um componente dedicado de detecção, previsão e resolução de colisões **entre NPCs**, separado tanto do gerenciador de trânsito quanto do sistema de colisão jogador↔NPC da SPEC-005, preservando 100% dos comportamentos anteriores:

- **Previsão e janela de atividade**: avaliação contínua (orientada a eventos + atualização periódica configurável) dos pares de NPCs na mesma trajetória — tempo até o encontro (distância ÷ diferença de velocidade) comparado à janela de atividade conjunta (tempo até o descarte de cada um, margens da área visível, velocidades, movimento relativo e estado da pista). Só é potencial enquanto ambos ainda estiverem ativos; pares em trajetórias distintas ou de mesma velocidade nunca geram previsão.
- **Detecção e classificação**: interseção das áreas físicas configuráveis por categoria (mesmas hitboxes da SPEC-005) por quadro sobre pares candidatos, classificados em exatamente um de dois tipos — **longitudinal** ou **lateral** — pela geometria do contato, com identificação determinística de causador/atingido e intensidade derivada da velocidade relativa (mesma normalização da SPEC-005).
- **Resposta lateral exclusiva**: o NPC atingido recebe drift temporário (máquina de estados `normal → colisão → drift → recuperação → normal`) com direção derivada da posição relativa (margem neutra), direção invertida quando próximo da borda, e deslocamento **transferido ao causador** quando nenhum lado comporta — sempre limitado pelos limites vigentes da pista por altura. **Nenhuma mudança de velocidade em nenhuma fase, para nenhum envolvido** (FR-017); o causador nunca sofre drift automático.
- **Controles de cadeia**: efeito dominó com identificador de cadeia, profundidade máxima, tempo de expiração e registro de veículos já processados (0 loops); cadeias paralelas independentes (Clarification 5); novo impacto substitui o drift em curso (Clarification 4); cooldown **por par** (não global), com rearmento somente após separação.
- **Integração**: validação de spawn no `TrafficManager` (outra posição → outra faixa → **adiar para o quadro seguinte** e revalidar — Clarification 3), reavaliação quando a velocidade do jogador muda de forma relevante, encaminhamento de NPC→jogador ao sistema da SPEC-005 (exatamente 1 evento), evento informativo de 7 campos para specs futuras.

Todos os parâmetros ficam em `GameConfig` (FR-044); o desempenho é mantido com filtragem de pares candidatos, avaliação orientada a eventos e teto de 5 NPCs ativos (SC-019: meta 60 / piso 30 FPS).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7)

**Primary Dependencies**: Godot Engine 4.7 (viewport 640x480, stretch `viewport`, texture filter `nearest`); contratos existentes — `TrafficVehicle.get_occupied_area()`/`get_speed()`/`position` (SPEC-004), `Road.get_boundaries_for_player_y(y)` (SPEC-002), `CollisionSystem` (SPEC-005, intocado), `GameConfig.NPC_HITBOX_SIZES` (SPEC-005)

**Storage**: N/A (parâmetros no autoload `GameConfig`, estado em memória durante a partida, sem persistência)

**Testing**: GdUnit4, testes em `tests/unit/` (runner: `addons/gdUnit4/runtest.sh --headless`; suíte completa sai com exit 101 quando verde)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS como meta e 30 FPS como piso (SC-019), com jogador + até 5 NPCs ativos; avaliação de pares limitada a candidatos relevantes com atualização orientada a eventos + periódica (FR-008, FR-045), sem O(n²) completo por quadro

**Constraints**:
- Velocidade de NPC jamais alterada por colisão NPC×NPC, em nenhuma fase (FR-017, SC-014)
- Nenhum veículo sai dos limites válidos da pista, em nenhum quadro (FR-018, SC-006)
- Nenhum parâmetro fixo na lógica — tudo em `GameConfig` (FR-044, SC-017)
- Sem duplicação da lógica de colisão jogador↔NPC; encaminhamento ao SPEC-005 com exatamente 1 evento (FR-037/FR-038, SC-015)
- Zero regressão das SPECs 001–005 (SC-016); mudança mínima e aditiva nos sistemas existentes
- Sem física veicular realista, sem rotação/capotamento, sem decisão estratégica de NPCs (FR-043)

**Scale/Scope**: 9 user stories, 45 FRs, 19 SCs, 7 entidades-chave, 2 tipos de colisão, 4 categorias de NPC, teto de 5–12 ativos, ~15 parâmetros novos de configuração

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Nenhum controle novo; os 4 controles existentes permanecem intactos (Dificuldade: "não aumentar dificuldade com controles desnecessários"). A complexidade vai para a resposta lateral do trânsito, não para o jogador |
| II. Prioridade da Experiência do Jogador | ✅ PASS | Modelo arcade previsível e controlado (FR-043); colisão NPC×NPC nunca interrompe a partida nem derruba veículo; consequência perceptível (drift lateral) garantida |
| III. Arquitetura Modular | ✅ PASS | Componente próprio `NpcCollisionSystem` separado do trânsito (FR-036) e do `CollisionSystem` (FR-037); veículos de trânsito apenas expõem identificação, posição, área e estado — não detectam nem resolvem colisões (§Trânsito, FR-039); comunicação por sinal (FR-041) |
| IV. Design Orientado a Configuração | ✅ PASS | FR-044/SC-017: ~15 parâmetros novos (`npc_*`) centralizados em `GameConfig`, nenhum valor fixo na lógica |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Out of Scope explícito; escopo das cláusulas §Comportamento de Colisão e §Trânsito resolvido documentadamente nas Assumptions do spec (consequência NPC×NPC = deslocamento lateral; sem velocidade/combustível nos NPCs) |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Documentação, comentários e mensagens em pt-BR; nenhum texto novo voltado ao jogador nesta feature |
| Regras de Jogabilidade — Pista (veículo nunca sai da área válida) | ✅ PASS | Invariante central: FR-018/FR-019 limitam todo deslocamento pelos limites vigentes por altura; SC-006/SC-018 verificam quadro a quadro |
| Regras de Jogabilidade — Física do Veículo (arcade, sem física realista) | ✅ PASS | FR-043: sem rotação, capotamento, frenagem inteligente ou decisão estratégica |
| Regras de Jogabilidade — Comportamento de Colisão | ✅ PASS (escopo resolvido) | Colisão produz consequência perceptível (drift + evento); sem Game Over; balanceamento por configuração (FR-044). O item "reduzir velocidade/consumir combustível" aplica-se ao veículo do jogador — Assumptions do spec |
| Regras de Jogabilidade — Trânsito | ✅ PASS | Veículos fornecem id/posição/área/estado; geração separada do comportamento individual; detecção em componente dedicado (FR-036/FR-039) |
| Regras de Jogabilidade — Dificuldade | ✅ PASS | `npc_max_active` é projeção somente leitura do teto por dificuldade do SPEC-004 (FR-042, fonte única, sem valor próprio); demais parâmetros em dados/configuração |
| Câmera e Apresentação | ✅ PASS | Sem mudança visual/renderização; deslocamento é translacional em pixel art, com escala/proporções preservadas |
| Estratégia — Disciplina de Mudanças | ✅ PASS | Escopo mínimo: arquivos novos em `src/collision/` + hooks aditivos em `traffic_vehicle.gd`, `traffic_manager.gd`, `game_config.gd`, `gameplay_manager.gd`; nada reescrito |
| Testes | ✅ PASS | Lógica determinística crítica coberta (detecção, classificação, cadeia, cooldown, spawn, limites); spawn/selecionar/posicionar com cobertura automatizada MUST; suítes novas planejadas em `tests/unit/` |
| Qualidade de Código | ✅ PASS | Scripts de responsabilidade única (sistema, drift por veículo, cadeia, payload do evento); máquina de estados explícita; sem números mágicos |
| Performance | ✅ PASS | FR-008/FR-045: filtragem de pares candidatos + eventos (spawn/reciclagem/deslocamento) + atualização periódica configurável; sem criar objetos por quadro; detecção limitada aos objetos relevantes |
| Independência de Assets | ✅ PASS | Áreas físicas derivadas de `GameConfig` (hitboxes por categoria), nunca de sprites/arquivos |

**Resultado: Todos os gates PASS contra a constitution v2.0.0. Sem violações a justificar.**

**Re-check pós-design (Fase 1)**: os artefatos gerados (`research.md` R1–R10, `data-model.md`, `contracts/`) confirmam os gates — quatro scripts novos de responsabilidade única (III), hooks aditivos somente em `position.x`/chamada de spawn (Disciplina de Mudanças), ~16 parâmetros `npc_*` em `GameConfig` (IV), avaliação orientada a eventos + periódica sem alocação por quadro (Performance), hitboxes por configuração (Independência de Assets) e escrita em velocidade **inexistente por construção** (R10 — §Comportamento de Colisão/Trânsito). **Resultado: PASS, nenhuma violação nova.**

## Project Structure

### Documentation (this feature)

```text
specs/006-npc-collision-system/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (evento NPC×NPC, APIs consumidas, validação de spawn)
├── checklists/          # requirements.md (gerado pelo /speckit.specify)
└── tasks.md             # Phase 2 output (/speckit.tasks — NÃO criado aqui)
```

### Source Code (repository root)

```text
src/
├── collision/
│   ├── npc_collision_system.gd     # NOVO: previsão, detecção, classificação, cadeia,
│   │                               #   cooldown por par, validação de spawn, reavaliação,
│   │                               #   encaminhamento ao CollisionSystem, evento
│   ├── npc_collision_data.gd       # NOVO Resource: payload de 7 campos (FR-041)
│   ├── npc_drift_state.gd          # NOVO: estados normal→colisão→drift→recuperação→normal
│   │                               #   (1 por veículo; substituição em novo impacto)
│   ├── npc_chain_state.gd          # NOVO: cadeia ativa (id, profundidade, expiração,
│   │                               #   conjunto de processados)
│   ├── collision_system.gd         # INALTERADO (SPEC-005 — jogador↔NPC)
│   ├── collision_data.gd           # INALTERADO (SPEC-005)
│   ├── drift_state.gd              # INALTERADO (SPEC-005 — jogador)
│   └── npc_overtake_state.gd       # INALTERADO (SPEC-005 — ultrapassagem)
├── config/
│   └── game_config.gd              # + parâmetros npc_* (FR-044) — bloco SPEC-006
├── traffic/
│   ├── traffic_vehicle.gd          # + gancho aditivo de drift (só posição, clamp por bounds;
│   │                               #   velocidade intocada, FR-017) + expõe estado de drift
│   └── traffic_manager.gd          # + chamada à validação de spawn (FR-028/FR-029) com
│                                   #   adiamento para o quadro seguinte; sem lógica de colisão
├── road/
│   └── road.gd                     # consumo SOMENTE-LEITURA dos limites por altura (FR-040)
└── game/
    └── gameplay_manager.gd         # wiring do NpcCollisionSystem (após o trânsito, como o SPEC-005)

tests/unit/
├── npc_prediction_test.gd          # US2/US8: janela de atividade, trajetórias distintas,
│                                   #   mesma velocidade, reavaliação pós-mudança de velocidade
├── npc_collision_detection_test.gd # US1/US3: interseção, classificação longitudinal/lateral,
│                                   #   causador/atingido, intensidade
├── npc_collision_drift_test.gd     # US1/US3/US6: direção, substituição de drift, fases,
│                                   #   velocidade inalterada em todas as fases
├── npc_collision_bounds_test.gd    # US4: inversão de lado na borda, transferência ao causador,
│                                   #   limites por altura nas transições 2↔4 vias
├── npc_collision_chain_test.gd     # US5: A→B→C, profundidade máx., 0 loops, caducidade,
│                                   #   cadeias paralelas com ids próprios
├── npc_collision_cooldown_test.gd  # US5: cooldown por par (A↔B bloqueado, B↔C livre),
│                                   #   rearmento após separação
├── npc_collision_spawn_test.gd     # US7: recusa/reposicionamento, adiamento ao quadro
│                                   #   seguinte, conflito pós-descarte não bloqueia
├── npc_collision_event_test.gd     # US6: evento com 7 campos, um por colisão válida
└── npc_collision_regression_test.gd# US9: encaminhamento NPC→jogador (1 evento SPEC-005),
                                    #   teto de 5 NPCs, integridade das suítes anteriores
```

**Structure Decision**: Opção 1 (projeto único Godot). A feature segue o padrão de módulo por sistema já estabelecido (`src/collision/` desde a SPEC-005): os quatro scripts novos têm responsabilidade única (coordenação, estado por veículo, cadeia, payload), e os hooks em `TrafficVehicle`, `TrafficManager` e `GameplayManager` são mínimos e aditivos — sem alteração de comportamento quando não há colisão NPC×NPC (SC-016).

## Complexity Tracking

> Sem violações da constituição — seção vazia.
