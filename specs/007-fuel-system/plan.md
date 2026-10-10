# Implementation Plan: Sistema de Combustível

**Branch**: `007-fuel-system` | **Date**: 2026-10-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-fuel-system/spec.md`

## Summary

Implementar o **sistema de combustível** como componente próprio (nomeado explicitamente pela constituição §III), mantendo o estado do tanque, calculando o consumo pelo tempo decorrido e pela velocidade, aplicando penalidades de colisão por ambiente e emitindo os três eventos da spec — sem tocar em movimento, colisão, estados ou física:

- **Consumo**: por quadro dentro do ramo `PLAYING`, `taxa = consumo_mínimo + normalizada * fator`, com teto de `consumo_máximo`, `normalizada = clamp(velocidade / velocidade_máxima, 0, 1)` e, em velocidade zero, o consumo em repouso configurável. Subtração `taxa * delta` com clamp `[0, capacidade]` — independente da taxa de quadros (FR-005, SC-003).
- **Penalidades por colisão**: consumidor do sinal `collision_occurred` da SPEC-005 (já deduplicado por cooldown + sobreposição lá) — cada evento vale exatamente 1 desconto; o valor vem do mapa `collision_fuel_penalty[ambiente]` lido no **momento do evento** a partir de `GameConfig.current_environment_id` (PLAINS/DESERT 0, FOREST/ICE pequeno e equivalente), sempre limitado ao zero. Colisões NPC×NPC (SPEC-006) nunca chegam aqui.
- **Eventos únicos**: `fuel_changed(current, max)` a cada variação real; `fuel_low` por travessia do limiar (`atual/capacidade <= limite`, latch rearmed no reset); `fuel_depleted` exatamente 1× por esgotamento (latch rearmed no reset), qualquer que seja a origem. Após esgotado: sem consumo, sem valor negativo, sem novo evento.
- **Vida útil**: `reset()` disposta na transição **READY → PLAYING** (não em PAUSED → PLAYING); consumo roda apenas no ramo `PLAYING` do `GameplayManager._process`. Integração com estados/vitória/Game Over fica na SPEC-008, consumindo os eventos já existentes (FR-033).
- **HUD mínimo (Clarification 2026-10-09)**: primeira interface do projeto — `CanvasLayer` com barra (dois `ColorRect` planos: trilho + preenchimento por razão `atual/capacidade`) e rótulo estático "BAIXO" (texto vindo de `GameConfig`, §VI), mudando de cor e exibindo o rótulo enquanto o estado baixo persistir. Observa; nunca modifica o combustível.
- **Configuração**: bloco `## Combustível (SPEC-007)` no `GameConfig` com os `fuel_*` + `collision_fuel_penalty` + rótulo — nenhum valor fixo na lógica (FR-026, constituição §IV, que lista `fuel_capacity`/`fuel_consumption_rate`/`collision_fuel_penalty` como exemplos). Valores-semente provisionais, calibrados por testes de gameplay (FR-028).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7.2)

**Primary Dependencies**: contrato da SPEC-005 `CollisionSystem.collision_occurred(data: CollisionData)` (`specs/005-collision-drift-system/contracts/collision_event.md`), `GameConfig` (autoload — `current_environment_id`, `max_speed`, novos `fuel_*`), `PlayerVehicle.get_speed()` (SPEC-001), estados `GameState` (READY/PLAYING/PAUSED — transição `begin_playing()`), viewport 640×480 stretch `viewport`

**Storage**: N/A (parâmetros no autoload `GameConfig`, estado do tanque em memória durante a partida, sem persistência)

**Testing**: GdUnit4, testes em `tests/unit/` (35 suítes atuais + 6 novas = 41; runner: `addons/gdUnit4/runtest.sh --headless` — sai com exit 101 quando verde)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS como meta e 30 FPS como piso (mesmo patamar das SPECs 005/006) — o custo por quadro do FuelSystem é 1 leitura de velocidade, 1 multiplicação, clamps e no máximo 3 emissões de sinal; HUD atualiza por sinal (não por polling)

**Constraints**:
- `0 <= fuel_current <= fuel_capacity` em qualquer atualização; pós-esgotamento, 0 consumo e 0 eventos repetidos (FR-010/FR-019/FR-020, SC-007/SC-013)
- Exatamente 1 desconto por colisão válida da SPEC-005; 0 efeitos de colisões NPC×NPC (FR-013/FR-015, SC-010/SC-011)
- Penalidade sempre pelo ambiente do **momento** do evento, sem retroatividade (FR-016, SC-012)
- Nenhum parâmetro fixo na lógica — tudo em `GameConfig` (FR-026/FR-027, SC-016)
- FuelSystem não altera velocidade/física/estados e não implementa Game Over (FR-021, SC-017)
- HUD só observa (§Sistema de Combustível: "A UI SHOULD observar o sistema... em vez de modificar"); texto de UI externalizado (§VI)
- Zero regressão das SPECs 001–006 (SC-017); mudanças mínimas e aditivas

**Scale/Scope**: 5 user stories, 34 FRs, 19 SCs, 6 entidades, 4 ambientes com penalidade, ~10 parâmetros novos de configuração, 2 scripts novos (`fuel_system.gd`, `fuel_hud.gd`), 1 diretório novo (`src/ui/`), 6 suítes novas cobrindo os 27 testes obrigatórios

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Nenhum controle novo; combustível está nomeado no próprio princípio como fonte de desafio; a profundidade vem de administrar velocidade vs. trânsito |
| II. Prioridade da Experiência do Jogador | ✅ PASS | Indicador mínimo sem animações/sons (Clarification 2026-10-09); consumo administrável como meta de balanceamento (FR-028); sem Game Over abrupto nesta spec (pontaria de estados na SPEC-008) |
| III. Arquitetura Modular | ✅ PASS | `FuelSystem` é literalmente um dos módulos exigidos; componente próprio em `src/fuel/` com responsabilidade única; comunicação por sinais (`fuel_changed`, `fuel_low`, `fuel_depleted`, `collision_occurred`); HUD em `src/ui/` separado |
| IV. Design Orientado a Configuração | ✅ PASS | Os exemplos da constituição estão cobertos no bloco `GameConfig`: `fuel_capacity` e `collision_fuel_penalty` literalmente; `fuel_consumption_rate` pela família `fuel_consumption_idle/min/max/speed_factor` (taxa resultante = `min + normalizada × fator`), todos ajustáveis sem tocar na lógica (FR-026/FR-027); nenhum número mágico |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Nenhum item da lista proibida (armas, multiplayer, online, RPG...); escopo exatamente o núcleo previsto |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Docs/comentários em pt-BR; único texto de usuário novo ("BAIXO") externalizado em `GameConfig.fuel_low_label`, sem literal embutido na lógica (SHOULD de localização futura) |
| Regras — Veículo do Jogador | ✅ PASS | "Consumir combustível enquanto se move" é exatamente FR-004/FR-006; velocidade máxima/aceleração/frenagem intocadas |
| Regras — Comportamento de Colisão | ✅ PASS (emenda v3.0.0) | O item "consumir combustível adicional" foi **qualificado por emenda constitucional v3.0.0 (2026-10-10)**: o MUST vale segundo a penalidade configurável do ambiente vigente, admitindo valor zero em PLAINS/DESERT como alavanca de progressão de §Dificuldade — o mecanismo cobre os 4 ambientes via `collision_fuel_penalty` (§IV); Redução de velocidade, deriva e feedback visual vêm da SPEC-005; somoro adiado com o áudio global. Origem: decisão do usuário de 2026-10-09, formalizada na emenda |
| Regras — Sistema de Combustível | ✅ PASS (emenda v3.0.0) | Implementa: capacidade/consumo/penalidade configuráveis, clamp anti-negativo (FR-010), sistema independente da UI e UI apenas observa (FR-024/FR-025), gatilho único de esgotamento (FR-018/FR-019). O MUST "estado de falha ao zerar" foi **reescrito por emenda v3.0.0**: sinal único de esgotamento com o sistema de combustível, transição com o sistema central de estado de jogo (SPEC-008) — 007 emite `fuel_depleted`, 008 chama `game_state.game_over()` (FR-021/FR-033, Out of Scope); janela 007→008 documentada em Complexity Tracking |
| Regras — Pista / Trânsito / Física | ✅ PASS | Nenhuma alteração: pista e trânsito intocados; física do veículo intocada (consumo não mexe em velocidade, FR-021/FR-030) |
| Regras — Estado de Jogo | ✅ PASS | Nenhum objeto decide estado global: `FuelSystem` só emite `fuel_depleted`; MENU/READY/PLAYING/PAUSED permanecem com `GameState`; VICTORY/GAME_OVER são da SPEC-008 |
| Regras — Dificuldade | ✅ PASS | Penalidades por ambiente são exatamente a alavanca "consequências de colisão" orientada a dados; 4 controles intactos |
| Câmera e Apresentação | ✅ PASS | HUD em `CanvasLayer` com retângulos planos e escala inteira (pixel-art preservada); sem suavização; lógica independente de assets (§Independência de Assets) |
| Estratégia — Fase 4 (Combustível) | ✅ PASS | Esta spec é a Fase 4: capacidade, consumo, HUD de combustível, esgotamento — menos Game Over (SPEC-008). Fase 3 (penalidade por colisão) é entrega conjunta natural, já que o evento da SPEC-005 existe |
| Estratégia — Disciplina de Mudanças | ✅ PASS | 2 scripts novos + bloco de config + wiring pontual em `gameplay_manager.gd` + CanvasLayer na cena; nenhum sistema existente é reescrito |
| Testes | ✅ PASS | A constituição lista "consumo de combustível, esgotamento, penalidade de combustível por colisão" como críticos — os 27 testes obrigatórios da spec cobrem exatamente isso; 6 suítes novas |
| Qualidade de Código | ✅ PASS | Script de responsabilidade única; latches explícitos e nomeados; sem números mágicos (tudo em `GameConfig`); comentários em pt-BR |
| Performance | ✅ PASS | 1 multiplicação + clamps por quadro; emissões por mudança real; HUD orientado a eventos; sem alocação por quadro |
| Independência de Assets | ✅ PASS | Barra construída com `ColorRect` (não sprite), razão numérica vinda do sistema, texto via config — trocar arte de UI não toca na lógica |

**Resultado: PASS — 0 violações pendentes. Os 2 gates antes registrados como JUSTIFICADOS (§Comportamento de Colisão e §Sistema de Combustível) foram resolvidos pela emenda constitucional v3.0.0 (2026-10-10), executada após o /speckit.analyze desta feature (achados C1/C2) com aprovação do usuário; ver Complexity Tracking.**

**Re-check pós-design (Fase 1)**: gerados `research.md` (R1–R12), `data-model.md` (6 entidades), `contracts/fuel_events.md` + `contracts/consumed_apis.md` + `contracts/hud_indicator.md` e `quickstart.md`. **Nenhuma violação nova**: as decisões de design reforçam os princípios — FuelSystem isolado em `src/fuel/` sem dependência de estado global (§III); todos os `fuel_*` + `collision_fuel_penalty` + `fuel_low_label` em `GameConfig`, zero literais na lógica (§IV/§VI); HUD com `ColorRect`/texto de config, sem assets (§Independência de Assets) e puramente observador (§Sistema de Combustível); eventos por sinal com custo por quadro de uma multiplicação (§Performance); 27 testes cobrem consumo/esgotamento/penalidade (§Testes — críticos listados). Os gates antes pendentes são **§Comportamento de Colisão** e **§Sistema de Combustível**, ambos resolvidos pela **emenda constitucional v3.0.0 (2026-10-10)** e registrados no Complexity Tracking. **Resultado do re-check: PASS (0 pendências).**

## Project Structure

### Documentation (this feature)

```text
specs/007-fuel-system/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (eventos emitidos, APIs consumidas, contrato do HUD)
├── checklists/          # requirements.md (gerado pelo /speckit.specify)
└── tasks.md             # Phase 2 output (/speckit.tasks — NÃO criado aqui)
```

### Source Code (repository root)

```text
src/
├── fuel/
│   └── fuel_system.gd           # NOVO: estado do tanque, consumo por delta×velocidade,
│                                #   penalidade por ambiente via evento da SPEC-005,
│                                #   latches de baixo/esgotado, sinais fuel_*
├── ui/
│   └── fuel_hud.gd              # NOVO: 1ª UI do projeto — barra (ColorRect trilho+
│                                #   preenchimento) + rótulo "BAIXO"; só observa
├── config/
│   └── game_config.gd           # + bloco ## Combustível (SPEC-007): fuel_capacity,
│                                #   fuel_initial_amount, fuel_consumption_idle/min/max,
│                                #   fuel_consumption_speed_factor, fuel_low_threshold,
│                                #   collision_fuel_penalty (mapa por ambiente),
│                                #   fuel_low_label
├── game/
│   ├── gameplay_manager.gd      # + instância do FuelSystem; reset em READY→PLAYING;
│                                #   update(delta, get_speed()) no ramo PLAYING;
│                                #   collision_occurred → FuelSystem; conexões do HUD
│   └── gameplay.tscn            # + CanvasLayer "FuelHudLayer" (Control + ColorRect×2 + Label)
├── player/
│   ├── player_vehicle.gd        # INALTERADO (expõe get_speed() — SPEC-001)
│   └── vehicle_controller.gd    # INALTERADO (fonte de speed/max_speed)
└── collision/
    └── collision_system.gd      # INALTERADO (emite collision_occurred — SPEC-005)

tests/unit/
├── fuel_consumption_test.gd     # US1 / testes 1–10: init cheio/configurado, velocidades
│                                #   baixa/alta/constante, aceleração, liberação, frenagem,
│                                #   repouso, taxas de atualização, limites
├── fuel_collision_penalty_test.gd # US2 / testes 16–25: 4 ambientes, equivalência,
│                                #   acúmulo, sem duplicação, NPC×NPC=0, troca de ambiente,
│                                #   clamp a zero
├── fuel_depletion_test.gd       # US3 / testes 11–14: esgotamento exato, sem negativo,
│                                #   sem consumo pós-zero, fuel_depleted 1×
├── fuel_low_event_test.gd       # US4 / teste 15: detecção de combustível baixo (limiar)
├── fuel_hud_test.gd             # US4 / teste 26: barra/rótulo acompanham; UI não modifica
└── fuel_config_test.gd          # US5 / teste 27: parâmetros refletem sem tocar na lógica
```

**Structure Decision**: Opção 1 (projeto único Godot). Segue o padrão "um módulo por sistema" consolidado desde a SPEC-005: `src/fuel/` espelha `src/collision/`, e `src/ui/` inaugura a camada de apresentação com um único script de responsabilidade única. Os pontos de contato com código existente são mínimos e aditivos: bloco novo no `GameConfig`, wiring no `GameplayManager` (instância, reset, update, conexões) e um `CanvasLayer` na cena — `CollisionSystem`, `VehicleController`, `Road` e `TrafficManager` permanecem intocados (SC-017).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| ~~§Comportamento de Colisão — "uma colisão MUST consumir combustível adicional"~~ **RESOLVIDO pela emenda v3.0.0 (2026-10-10)** | O MUST foi qualificado por emenda: vale segundo a penalidade configurável do ambiente vigente, com valor zero admitido em PLAINS/DESERT (alavanca de progressão de §Dificuldade). Origem: design aprovado do usuário (testes 16/17 afirmam perda exatamente zero; progressão: ambientes iniciais só afetam dirigibilidade) | Penalidade > 0 em todos os ambientes — rejeitado: contradiz o design explícito da spec e invalida os testes de aceitação 16/17. O caminho escolhido (emenda) foi exigido pelo /speckit.analyze: justificativa em plan não bastava para um MUST |
| ~~§Sistema de Combustível — estado de falha ao zerar~~ **RESOLVIDO pela emenda v3.0.0 (2026-10-10)** | O MUST foi reescrito: sinal único de esgotamento com o sistema de combustível + transição para o estado de falha com o sistema central de estado de jogo, podendo ser entregue por spec posterior (008). 007 entrega `fuel_depleted` testado; 008 chama `game_state.game_over()` (já existe, nunca chamado — verificado em `src/`); janela 007→008 documentada até a SPEC-008; §Estratégia trata a Fase 4 como unidade da qual 007/008 são fatias | Game Over dentro da 007 — rejeitado: contradiz FR-021/FR-033/Out of Scope aprovados e o desenho de duas specs (008 já é a próxima feature) |
