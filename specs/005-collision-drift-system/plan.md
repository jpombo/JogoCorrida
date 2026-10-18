# Implementation Plan: Sistema de Colisão e Drift

**Branch**: `005-collision-drift-system` | **Date**: 2026-10-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-collision-drift-system/spec.md`

## Summary

Implementar o sistema de colisão e drift arcade entre o jogador e os veículos de trânsito, mantendo total independência de sprite e preservando o comportamento das SPECs anteriores quando não há contato:

- **Detecção e classificação**: interseção de hitboxes retangulares configuráveis por quadro (`Rect2.intersects`), classificada em exatamente 3 tipos (jogador→traseira NPC, lateral, NPC→traseira jogador) pela posição relativa dos centros, com margem neutra determinística.
- **Consequências para o jogador**: perda de velocidade proporcional à intensidade (máquina de estados `normal → impacto → drift → recuperação → normal`), drift lateral com controle parcial configurável e recuperação gradual até 100%.
- **Ultrapassagem do NPC (tipo 1-3)**: deslocamento lateral temporário do NPC para o lado oposto, sem redução de velocidade, limitado pelos limites vigentes da estrada, com retorno à trajetória normal.
- **Robustez**: cooldown por par jogador↔NPC, limites de estrada consultados por altura em todos os deslocamentos, evento de colisão desacoplado para specs futuras (combustível), nenhuma alteração nos sistemas anteriores sem contato.

Todo o ajuste é feito por novos parâmetros em `GameConfig` (FR-035); a detecção consome `TrafficVehicle.get_occupied_area()` (FR-025 do SPEC-004) e os limites vigentes do `Road¦TrackManager`, sem alterar a criação, movimentação ou reciclagem do trânsito (FR-033).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7)

**Primary Dependencies**: Godot Engine 4.7 (viewport 640x480, stretch `viewport`, texture filter `nearest`); contratos existentes `TrafficVehicle.get_occupied_area()`, `Road`/`TrackManager` (limites por altura), `VehicleController` (controle lateral do jogador)

**Storage**: N/A (parâmetros em autoload `GameConfig`, sem persistência externa)

**Testing**: GdUnit4, testes em `tests/unit/` (runner: `addons/gdUnit4/runtest.sh --headless`)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS como meta, 30 FPS como piso, com colisões contínuas nos 4 ambientes (SC-011); detecção O(n) por quadro sobre NPCs ativos (pool ≤ dúzias — custo desprezível)

**Constraints**:
- Hitboxes retangulares independentes dos sprites, configuráveis por veículo/categoria (FR-006–FR-008)
- Nenhuma alocação por quadro na detecção (conforme padrão de pools do SPEC-004)
- Nenhum comportamento anterior alterado quando não há contato (FR-034, SC-010)
- Nenhum efeito sobre combustível/dano/pontuação — somente emissão de evento (FR-030, FR-031)

**Scale/Scope**: 8 user stories, 35 FRs, 12 SCs, 3 tipos de colisão, 4 categorias de NPC, 1 pool de pares em cooldown, 5 entidades-chave

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Nenhum controle novo; o drift reduz temporariamente a eficácia dos 4 controles existentes (FR-013), reforçando o desafio via colisões — exatamente o mecanismo previsto pelo princípio |
| II. Prioridade da Experiência do Jogador | ✅ PASS | Modelo arcade translacional (Assumptions: sem rotação/capotamento); NPC não é penalizado (FR-016, FR-017) — experiência acima de sofisticação técnica |
| III. Arquitetura Modular | ✅ PASS | `CollisionSystem` separado do `TrafficManager` (FR-033); comunicação por sinal/evento (FR-029/FR-030); responsabilidade única por script |
| IV. Design Orientado a Configuração | ✅ PASS | FR-035: todos os parâmetros de colisão/drift em `GameConfig`, nenhum valor fixo na lógica (SC-012) |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Out of Scope explícito alinhado à lista da constituição; colisão NPC×NPC e com decoração proibidas (FR-031) |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Documentação em pt-BR; nenhum texto novo voltado ao jogador nesta feature |
| Câmera e Apresentação | ✅ PASS | Nenhuma mudança visual/renderização; drift é deslocamento translacional dentro dos limites |
| Independência de Assets | ✅ PASS | FR-008/SC-009: lógica nunca consulta sprite nem nome de arquivo; hitbox é dado de configuração |
| Performance | ✅ PASS | Detecção a cada quadro sem degradar 60/30 FPS (SC-011, Edge Case "Desempenho") |
| Testes | ✅ PASS | Cobertura MUST de detecção, classificação, cooldown e limites prevista (testes por unidade em `tests/unit/`, padrão GdUnit4 estabelecido) |
| Qualidade de Código | ✅ PASS | Scripts de responsabilidade única; máquina de estados explícita (FR-015) |

**Resultado: Todos os gates PASS contra a constitution v2.0.0. Sem violações a justificar.**

## Project Structure

### Documentation (this feature)

```text
specs/005-collision-drift-system/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (evento de colisão + APIs consumidas)
└── tasks.md             # Phase 2 output (/speckit.tasks — NÃO criado aqui)
```

### Source Code (repository root)

```text
src/
├── collision/
│   ├── collision_system.gd       # Detecção, classificação, cooldown por par, evento
│   ├── collision_data.gd         # Resource: tipo, intensidade, direção, par envolvido
│   ├── drift_state.gd            # Máquina de estados do drift do jogador (FR-015)
│   └── npc_overtake_state.gd     # Deslocamento de ultrapassagem do NPC (tipo 1-3)
├── config/
│   └── game_config.gd            # + parâmetros colisão/drift/hitboxes (FR-035)
├── player/
│   └── vehicle_controller.gd     # + gancho de controle reduzido (fator do drift)
├── traffic/
│   └── traffic_vehicle.gd        # + deslocamento lateral de ultrapassagem (sem tocar velocidade)
├── road/                         # consumo somente-leitura dos limites por altura
└── game/
    └── gameplay_manager.gd       # wiring do CollisionSystem

tests/unit/
├── collision_detection_test.gd
├── collision_classification_test.gd
├── collision_drift_test.gd
├── collision_cooldown_test.gd
├── collision_overtake_test.gd
├── collision_event_test.gd
└── collision_hitbox_test.gd
```

**Structure Decision**: Opção 1 (projeto único Godot), novo módulo `src/collision/` seguindo o padrão de pastas por sistema já estabelecido (src/player, src/traffic, src/road...). O `CollisionSystem` é o único ponto novo de coordenação; os hooks no `VehicleController` e no `TrafficVehicle` são minimais e aditivos (não alteram comportamento sem colisão — FR-034).

## Complexity Tracking

> Sem violações da constituição — seção vazia.

## Ajustes Pós-Implementação (2026-10-05)

Validação manual do usuário após a convergência gerou 6 ajustes (registro completo em `tasks.md` Phase 13 e nas clarificações das specs correspondentes):

| # | Ajuste | Spec | Onde |
|---|--------|------|------|
| 1 | Separação retangular mínima entre NPCs no nascimento (`traffic_min_separation`) | SPEC-004 | `traffic_manager.gd`, `test_traffic_separation.gd`, FR-019 |
| 2 | Velocidades de categoria preservadas por corredor lateral (comboio só conta o líder do mesmo corredor) | SPEC-004 | `traffic_manager.gd`, `test_memory_stability.gd`, SC-029 |
| 3 | Densidade mínima (≥3 na estrada junto ao jogador) com reposição imediata por quadro e teto por dificuldade (máx. 5 visíveis em Gelo) | SPEC-004 | `traffic_manager.gd`, `test_traffic_density.gd`, FR-063/FR-064, SC-028 |
| 4 | Aceleração desconsiderada por janela configurável pós-colisão (frenagem válida; inerte sem colisão) | SPEC-005 | `vehicle_controller.gd`, `collision_system.gd`, `collision_accel_lockout_test.gd`, FR-036/SC-013 |
| 5 | Travamento de velocidade entre categorias: faixas laterais reservadas por velocidade, corredor = interseção das projeções laterais e espaçamento mínimo do limitador derivado das meias-alturas (caminhão sai na própria taxa, não preso no esporte) | SPEC-004 | `traffic_manager.gd`, `test_traffic_speed_ordering.gd`, `test_memory_stability.gd`, FR-019/FR-065, SC-006/SC-030 |
| 6 | Retorno do NPC à faixa de origem ao fim da ultrapassagem (o deslocamento deixava o NPC 40 px fora da faixa da sua velocidade, invadindo o corredor de outra categoria e fazendo o limitador acoplar as velocidades) | SPEC-005 | `npc_overtake_state.gd`, `traffic_vehicle.gd`, `game_config.gd`, `collision_overtake_test.gd`, FR-019/FR-021, SC-014 |

Todos seguem o princípio IV (design orientado a configuração): nenhum valor fixo na lógica. Suíte completa ao final: 24 suítes, 160 casos, 0 falhas (exit 101).
