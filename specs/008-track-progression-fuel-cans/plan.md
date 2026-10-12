# Implementation Plan: Progressão da Pista, Estados do Jogo, Combustível e Itens Coletáveis

**Branch**: `008-track-progression-fuel-cans` | **Date**: 2026-10-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-track-progression-fuel-cans/spec.md`

## Summary

Integrar o ciclo completo de corrida — menu com seleção de veículo, progressão finita da pista com marcações de início/chegada, dimensionamento do combustível pela distância, transição para `VICTORY`/`GAME_OVER`, pausa/reinício/menu com telas, e galões coletáveis — preservando as SPEC-001 a SPEC-007:

- **Progressão (`TrackManager` — constituição §III)**: novo componente em `src/track/` que integra por quadro a **velocidade de avanço** (o mesmo `get_speed()` que impulsiona a rolagem; troca de faixa soma zero — Clarification 2026-10-10) em km, com conversão derivada de `KMH_TO_SPEED_UNIT`; mantém percorrida/total/restante/percentual e a posição lógica da chegada; nunca decresce nem ultrapassa o total.
- **Marcações**: `INÍCIO` e `CHEGADA` como elementos do mundo da pista (banda quadriculada + rótulo externado), construídos com `ColorRect`/`Label` (sem sprite novo), deslocados pela própria rolagem; o início é descartado ao sair da tela; a vitória é o **cruzamento geométrico completo** da banda da chegada pelo jogador (não `percorrida == total`), com combustível disponível no instante.
- **Combustível**: capacidade/carga inicial derivadas em execução (`distância × consumo_base_por_unidade + margem`) via novo método `FuelSystem.definir_capacidade_derivada()` chamado antes do `reset()` (o caminho SPEC-007 continua intacto sem override); novo `FuelSystem.restaurar(valor)` como interface pública única de coleta (clamp, sem rearme, sem efeito de colisão); bloqueio de aceleração com zero por flag nova em `VehicleController` derivada do valor atual; `GAME_OVER` ao parar com zero e sem concluir (uma vez), `VICTORY` ao cruzar com combustível.
- **Galões (`FuelCanManager` — `src/items/`)**: pool próprio estilo `TrafficManager`; sem velocidade própria (só rolagem — Clarification); geração orientada por distância com taxa por ambiente, piso/teto do **total por corrida**, teto de ativos, espaçamentos e validação de posição livre de NPCs; coleta por sobreposição em `PLAYING`, sem pipeline de colisão; não coletado que sai da tela volta ao pool.
- **Ciclo de estados**: `UIManager` novo em `src/ui/` (menu, pausa, vitória, Game Over, indicador de distância — tudo observador e com textos externalizados); orquestração de reset completa no início de corrida/reinício (reset novo em Road, Traffic, colisões, decoração, player, track, galões — hoje só o FuelSystem é reiniciado); pausa congela a rolagem da estrada (hoje o `Road._process` continua com a última velocidade — correção exigida por FR-004).
- **Configuração**: bloco `## Progressão e Itens (SPEC-008)` no `GameConfig` com `track_*`, `fuel_consumption_per_distance`, `fuel_safety_margin`, `fuel_can_*` e rótulos de UI — sementes provisionais, calibradas por gameplay (FR-039, SC-016).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7.2)

**Primary Dependencies**: `GameState` (autoload — `victory()`/`game_over()` já existem e nunca foram chamados), `FuelSystem` (SPEC-007 — `reset()`, `get_atual()`, sinais `fuel_*`; +2 métodos públicos novos), `PlayerVehicle.get_speed()`/`change_sprite()` (SPEC-001), `Road` (`scroll_speed`, `get_boundaries_for_player_y()`, sinais de segmento), `TrafficManager.active_vehicles_snapshot` (SPEC-004), `CollisionSystem`/`NpcCollisionSystem` (SPEC-005/006 — só reset novo), `GameConfig` (autoload), `GameConfig.KMH_TO_SPEED_UNIT`, viewport 640×480 stretch `viewport`

**Storage**: N/A (parâmetros no autoload `GameConfig`; estado de corrida em memória; seleção de veículo vive na sessão, sem persistência)

**Testing**: GdUnit4, testes em `tests/unit/` (46 suítes atuais + ~9 novas; runner: `addons/gdUnit4/runtest.sh --headless` — sai com exit 101 quando verde)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS como meta e 30 FPS como piso (mesmo patamar das SPECs 005–007) — custo novo por quadro: 1 integração de distância, checagem de cruzamento geométrico, movimentação de ≤ `fuel_can_max_active` (teto 3) galões e sobreposição galão×jogador (n×1 com n pequeno); UI orientada a sinais, sem polling

**Constraints**:
- Distância só cresce com o componente de avanço em `PLAYING` (FR-007, Clarification de faixa); nunca decresce nem ultrapassa o total (SC-003/SC-004)
- Vitória só no cruzamento completo com combustível > 0 e `PLAYING`; esgotamento tem precedência no mesmo quadro (FR-013, casos de borda); 1 evento por corrida (SC-005)
- `GAME_OVER` só ao parar com zero e sem concluir; coleta nunca reativa corrida encerrada (FR-016/FR-017, SC-005/SC-007)
- Capacidade/carga derivadas em execução sem dupla fonte de verdade; limites válidos do FuelSystem continuam valendo (FR-018)
- Coleta de galão sem nenhuma consequência de colisão (FR-024, Clarification); geração só em `PLAYING`; piso/teto do total por corrida respeitados (Clarification, SC-010)
- `PAUSED` congela rolagem, consumo, progresso, trânsito, decoração, galões, temporizadores e verificação de chegada (FR-004)
- Nenhum parâmetro fixo na lógica; textos de usuário externalizados (FR-039/FR-041, constituição §IV/§VI)
- Zero regressão das SPECs 001–007 (SC-013/SC-014); dimensões e hitboxes dos veículos intocadas
- Interface só observa e emite comandos; transições de estado continuam centralizadas em `GameState` (FR-001/FR-005/FR-037)

**Scale/Scope**: 8 user stories, 41 FRs, 17 SCs, 6 entidades, ~20 parâmetros novos de configuração, 4–5 scripts novos (`track_manager.gd`, `track_markers.gd`, `fuel_can_manager.gd`, `fuel_can.gd`, `ui_manager.gd`), 2 diretórios novos (`src/track/`, `src/items/`), wiring aditivo em `gameplay_manager.gd`, `fuel_system.gd` (+2 métodos), `vehicle_controller.gd` (+1 flag), `game_config.gd` (+bloco) e resets novos em sistemas existentes; ~9 suítes novas cobrindo os 9 testes obrigatórios (A–I)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Nenhum controle novo — menu/pausa/telas usam as ações já existentes (`ui_accept`, `ui_cancel`, `ui_up/down/left/right`); a profundidade vem de distância, combustível e trânsito, todos nomeados no princípio |
| II. Prioridade da Experiência do Jogador | ✅ PASS | Tela de pausa com Continuar/Reiniciar/Voltar ao menu (Clarification); desaceleração gradual em vez de corte abrupto; galões dão recuperação jogável; escopo de apresentação mínimo (sem sons/animações) |
| III. Arquitetura Modular | ✅ PASS | `TrackManager` e `UIManager` são módulos literalmente exigidos; `FuelCanManager` é componente próprio de itens coletáveis (responsabilidade incompatível com trânsito — análise FR-027 em research R6), comunicando-se por sinais; reset orquestrado por chamadas explícitas, sem estado global |
| IV. Design Orientado a Configuração | ✅ PASS | Bloco `## Progressão e Itens (SPEC-008)` no `GameConfig`: `track_total_distance`, dimensionamento de combustível, todos os `fuel_can_*`, taxa por ambiente e rótulos de UI — nenhuma constante de balanceamento na lógica (FR-039, SC-016) |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Nenhum item da lista proibida; vitória/Game Over/pausa/menu são o núcleo previsto em §Pista/§Estado de Jogo; "postos de combustível"/itens extras seguem Out of Scope da spec |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Docs em pt-BR; todos os textos novos de usuário (menu, pausa, telas, `INÍCIO`/`CHEGADA`, formato de distância) externalizados em `GameConfig`, sem literais na lógica (FR-041) |
| Regras — Veículo do Jogador | ✅ PASS | Só o bloqueio de aceleração com combustível zero (flag derivada do valor atual — exigência do §Sistema de Combustível "não pode mais prosseguir"); velocidades/hitboxes intocadas |
| Regras — Comportamento de Colisão | ✅ PASS | Nenhuma alteração: pipeline SPEC-005 intacto; a coleta de galão explicitamente **não** é colisão (FR-024) e não passa pelo CollisionSystem |
| Regras — Sistema de Combustível | ✅ PASS | Implementa a entrega escalonada da emenda v3.0.0: 008 chama `GameState.game_over()` a partir do esgotamento; restauração via interface pública nova (`restaurar`), FuelSystem mantém autoridade exclusiva (FR-033/FR-038); capacidade derivada respeita clamp e limites |
| Regras — Pista | ✅ PASS | Pista finita com Início, Fim, distância e vitória ao alcançar o fim com combustível — exatamente o arco §Pista; estrada/rolagem só recebem reset e freeze na pausa |
| Regras — Trânsito | ✅ PASS | Intocada exceto `reset()` novo; galões não são veículos nem usam o TrafficManager (FR-027) |
| Regras — Estado de Jogo | ✅ PASS | As 6 transições passam a ser exercidas, sempre por `GameState` (`victory()`/`game_over()` já existentes); nenhum objeto de gameplay decide estado global (FR-001) |
| Regras — Dificuldade | ✅ PASS | Frequência de galões por dificuldade do ambiente é alavanca configurável; controles intactos |
| Câmera e Apresentação | ✅ PASS | Marcadores e galões no mundo da pista; bandas/labels com escala inteira e `TEXTURE_FILTER_NEAREST`; lógica independente de arte (§Independência de Assets) |
| Estratégia — Fase 5 (Conclusão da Pista) | ✅ PASS | Esta spec entrega a Fase 5 (distância, progressão, chegada, Vitória) e o restante da Fase 4 (Game Over, já com o sinal pronto da SPEC-007), além dos itens coletáveis do gerenciamento de combustível |
| Estratégia — Disciplina de Mudanças | ✅ PASS | Scripts novos isolados; alterações existentes aditivas (+métodos de reset, +flag, +2 métodos no FuelSystem, +bloco de config, wiring no GameplayManager); nenhum sistema funcional é reescrito |
| Testes | ✅ PASS | A constituição lista "progressão da pista, condição de vitória, condição de game over, consumo/esgotamento" como críticos — os 9 testes obrigatórios (A–I) cobrem exatamente isso; geração/reciclagem de galões com cobertura automatizada exigida (§Testes) |
| Qualidade de Código | ✅ PASS | Responsabilidade única por script; latches/guards explícitos; conversões derivadas de constantes existentes (não números soltos); comentários em pt-BR |
| Performance | ✅ PASS | Sem criação de objetos por quadro (pools); sobreposição limitada a ≤3 galões ativos; UI por sinal; marcadores movidos pela rolagem existente |
| Independência de Assets | ✅ PASS | Marcadores construídos com primitivas (`ColorRect`/`Label`); galões usam `gasolina.png` com hitbox de contato própria, independente do sprite; seleção de veículo troca textura sem tocar em física |

**Resultado: PASS — 0 violações. Nenhum gate pendente da SPEC-007 permanece: a janela 007→008 (transição para `GAME_OVER`) é fechada por esta spec.**

**Re-check pós-design (Fase 1)**: gerados `research.md` (R1–R13), `data-model.md` (6 entidades + mapeamento de código), `contracts/` (6 contratos) e `quickstart.md`. **Nenhuma violação nova**: `TrackManager`/`UIManager`/`FuelCanManager` são módulos de responsabilidade única comunicando-se por sinais (§III); todo parâmetro novo vive no `GameConfig` com fórmulas derivadas de constantes existentes (§IV); textos externalizados (§VI); coleta sem colisão preserva o pipeline SPEC-005 (§Comportamento de Colisão); `restaurar()` e `definir_capacidade_derivada()` mantêm o FuelSystem como única autoridade (§Sistema de Combustível); resets aditivos e freeze de pausa são mudanças mínimas (§Disciplina de Mudanças). **Resultado do re-check: PASS (0 pendências).**

## Project Structure

### Documentation (this feature)

```text
specs/008-track-progression-fuel-cans/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (track, restauração, galões, estados, UI, APIs consumidas)
├── checklists/          # requirements.md (gerado pelo /speckit.specify)
└── tasks.md             # Phase 2 output (/speckit.tasks — NÃO criado aqui)
```

### Source Code (repository root)

```text
src/
├── track/
│   ├── track_manager.gd        # NOVO: distância total/percorrida/restante/percentual,
│   │                           #   integração por quadro (só avanço em PLAYING), clamp ao
│   │                           #   total, sinal progress_changed, detecção de cruzamento
│   └── track_markers.gd        # NOVO: banda+rótulo INÍCIO (descartada ao sair da tela) e
│                               #   CHEGADA (posicionada no fim lógico, deslocada pela
│                               #   rolagem; vitória = cruzamento geométrico completo)
├── items/
│   ├── fuel_can.gd             # NOVO: sprite 32×51 (gasolina.png), área de contato,
│   │                           #   estado ativo/coletado, reset de reutilização
│   └── fuel_can_manager.gd     # NOVO: pool, geração orientada por distância (taxa por
│                               #   ambiente, piso/teto por corrida, teto de ativos,
│                               #   espaçamentos, validação livre de NPCs), movimento só
│                               #   pela rolagem, reciclagem na base, sinais spawned/collected
├── ui/
│   ├── fuel_hud.gd             # INALTERADO (SPEC-007)
│   └── ui_manager.gd           # NOVO: menu (seleção azul/vermelho), pausa (Continuar/
│                               #   Reiniciar/Voltar ao menu), vitória, Game Over e
│                               #   indicador de distância — só observa; comandos via
│                               #   sinais para o GameplayManager; textos de GameConfig
├── fuel/
│   └── fuel_system.gd          # + definir_capacidade_derivada(cap) e restaurar(valor)
│                               #   (interface pública da SPEC-008; reset() passa a
│                               #   respeitar o override; sem rearme; clamp idêntico)
├── player/
│   ├── player_vehicle.gd       # + reset() delegado ao controller + restauração de
│   │                           #   posição/sprite selecionado
│   └── vehicle_controller.gd   # + aceleracao_bloqueada_por_combustivel (flag inerte
│                               #   em false; checada junto do aceleracao_bloqueada da
│                               #   SPEC-005; limpa no reset())
├── road/
│   └── road.gd                 # + reset() (scroll_speed/scroll_offset/tipos) e
│                               #   update_scroll_speed(0) na pausa (FR-004)
├── traffic/
│   └── traffic_manager.gd      # + reset() (pool/ativos/reciclagem/crômetro/candidato)
├── collision/
│   ├── collision_system.gd     # + reset() (cooldowns/sobrepostos)
│   └── npc_collision_system.gd # + reset() (drifts/cadeias/janelas/cooldowns)
├── decoration/
│   └── decoration_manager.gd   # + reset() (elementos, baseline de scroll)
├── config/
│   └── game_config.gd          # + bloco ## Progressão e Itens (SPEC-008):
│                               #   track_total_distance, track_units_to_km,
│                               #   fuel_consumption_per_distance, fuel_safety_margin,
│                               #   fuel_can_* (restore, intervalo, espaçamentos, offsets,
│                               #   max_active, min/max per_race, spawn_rate por ambiente)
│                               #   e rótulos ui_* (menu, pausa, telas, INÍCIO/CHEGADA,
│                               #   formato de distância)
└── game/
    ├── gameplay_manager.gd     # + TrackManager/ FuelCanManager/ UIManager; seleção de
    │                           #   veículo; ordem canônica de atualização do PLAYING;
    │                           #   vitória/GAME_OVER; orquestração de reset (READY→PLAYING,
    │                           #   reinício, menu); freeze da rolagem na pausa; wiring de
    │                           #   restauração e de bloqueio por combustível
    └── gameplay.tscn           # + TrackLayer (markers), ItemsLayer (FuelCanManager) e
                                #   UI layer (CanvasLayer com menus/painéis/indicador)

tests/unit/
├── track_progression_test.gd   # Testes A/B (início, distância): crescimento só com avanço,
│                               #   faixa soma zero, pausa, clamp ao total, indicador
├── track_finish_test.gd        # Teste C (chegada): aproximação pela rolagem, cruzamento
│                               #   completo, 1× vitória, precedência do esgotamento
├── fuel_sizing_test.gd         # Teste D (dimensionamento): fórmula derivada, corrida
│                               #   de referência concluível, alteração da distância
├── fuel_game_over_flow_test.gd # Teste G: desaceleração, GAME_OVER 1×, coleta durante
│                               #   desaceleração, coleta não reativa, sem rearme
├── fuel_can_collection_test.gd # Teste E (coleta): 1× por galão, cap, sem colisão, pool
├── fuel_can_generation_test.gd # Teste F (geração/dificuldade): ordem de ambientes,
│                               #   piso/teto por corrida, espaçamentos, NPCs, pausa
├── ui_screens_test.gd          # Teste H (ciclo de vida): menu/pausa/fim, textos,
│                               #   observador puro
├── race_reset_test.gd          # Testes H/I: reset completo sem duplicatas/conexões
│                               #   repetidas; regressão de integração
└── game_config_008_test.gd     # Config reflete sem tocar na lógica (SC-016)
```

**Structure Decision**: Opção 1 (projeto único Godot). Segue o padrão "um módulo por sistema": `src/track/` e `src/items/` espelham `src/fuel/`/`src/collision/`; `src/ui/` é expandido com o `UIManager` (módulo exigido pela constituição §III). Os pontos de contato com código existente são aditivos: +2 métodos no `FuelSystem`, +1 flag no `VehicleController`, +`reset()` nos sistemas já existentes, +bloco de config e wiring no `GameplayManager` — nenhum sistema funcional é reescrito (SC-013/SC-014).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Nenhuma violação pendente — tabela vazia.
