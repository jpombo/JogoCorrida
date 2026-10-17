# Implementation Plan: Recordes, Persistência, Troféus, Pontuação e Obstáculos

**Branch**: `011-records-trophies-obstacles` | **Date**: 2026-10-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-records-trophies-obstacles/spec.md`

## Summary

A SPEC-011 adiciona ao JogoCorrida (Godot 4.7, GDScript, pt-BR) uma camada de progressão persistente entre sessões — recordes por modo, pontuação por corrida (distância + troféus − combustível perdido em colisões), troféus por conclusão dos quatro ambientes e desbloqueio permanente dos obstáculos no modo Relaxante — e dois novos obstáculos de pista (poça de água: desvio lateral de meio carro pelo lado do impacto, permanecendo inerte na pista até sair da tela [ajuste do aceite T032]; cascalho: efeito temporário configurável no veículo do jogador). O approach técnico segue os padrões já consolidados nas SPEC-007…010: componentes novos instanciados em código pelo `GameplayManager` (sem autoloads novos, sem mudanças em `gameplay.tscn`), `RefCounted` para lógica pura, pool com spawn por distância no padrão do `FuelCanManager`, efeito temporizado do cascalho no padrão de `aceleracao_bloqueada` do `VehicleController` (congelamento por `set_process(false)` fora de PLAYING), todos os números de balanceamento no `GameConfig` e guards nulos nos campos novos para preservar os testes sintéticos legados. A persistência usa o primeiro serviço de gravação do projeto: `SaveManager` (I/O puro de JSON em `user://progresso.json`, escrita atômica) + `ProgressManager` (domínio: recordes, histórico, acumulados, troféus, ciclos, desbloqueio derivado e a fórmula de pontuação). A gravação acontece uma única vez por encerramento, sempre no fim do ramo de vitória/derrota (cálculo → recorde → gravação — FR-008/FR-023).

## Technical Context

**Language/Version**: GDScript, Godot 4.7.2 (binário `Godot_v4.7.2-stable_linux.x86_64`); cena principal `res://src/game/gameplay.tscn`.

**Primary Dependencies**: Engine Godot apenas (sem plugins novos); GdUnit4 já presente em `addons/gdUnit4/`; assets já existentes `assets/trofeus/trofeu-{relaxante,normal,desafio}.png` (32×32), `assets/obstaculos/poca.png` (48×35), `assets/obstaculos/cascalho.png` (48×27) — nenhum asset novo a criar.

**Storage**: Primeira persistência do projeto — JSON em `user://progresso.json` via `FileAccess` + `JSON`, escrita em arquivo temporário + renomeio (nunca sobrescrever dados válidos com defaults). Carregamento tolerante a ausência/corrupção (fallback seguro para defaults em memória, sem travamento).

**Testing**: GdUnit4 em `tests/unit/` (suíte completa hoje: 68 suítes / 414 casos, exit 101); novas suítes `progress_*`, `save_*`, `obstacle_*`, `score_*`; lógica pura testada sem árvore de cena (padrão do projeto).

**Target Platform**: Desktop Godot (resolução base 640×480; suíte roda em `--headless`).

**Project Type**: Jogo 2D single-player; orquestração por `GameplayManager`.

**Performance Goals**: 60 fps com os sistemas atuais + obstáculos (pool ≤ 3 ativos, O(pool) por quadro); gravação só em encerramento (1 escrita por corrida); zero `_process` novo no `AudioManager`/`ProgressManager`/`SaveManager`.

**Constraints**: Suíte legada 100% verde sem ajuste (garantia R12 das specs anteriores); nenhuma mudança nos multiplicadores da SPEC-009 (FR-025); nenhum elemento novo de UI durante a corrida (FR-023); textos 100% via `GameConfig.ui_strings` (§VI).

**Scale/Scope**: ~4 arquivos-fonte novos (`save_manager.gd`, `progress_manager.gd`, `obstacle.gd`, `obstacle_manager.gd`), ~4 estendidos (`vehicle_controller.gd`, `fuel_system.gd`, `gameplay_manager.gd`, `ui_manager.gd`), 1 estendido de config (`game_config.gd`), ~6 suítes novas; nenhum sistema legado reescrito.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **§I Modularidade** — `src/save/` (I/O puro, zero domínio), `src/game/progress_manager.gd` (domínio puro, zero I/O e zero nós), `src/obstacles/` (pool + spawn, espelha `src/items/`). `ProgressManager` e `SaveManager` são `RefCounted` sem filhos; `ObstacleManager` é `Node` como `FuelCanManager`. Sem dependências novas de autoload/cena. **PASS**.
- **§II Índencia** — sem dependência nova entre domínio e engine além do padrão já usado (`Texture`/`FileAccess` no save e na UI); obstáculos reutilizam `road.get_boundaries_for_player_y`, snapshot do trânsito e `track_manager` como os galões. **PASS**.
- **§III Dependências diretas minimizadas** — `SaveManager` não conhece domínio (só Dictionary/JSON); `ProgressManager` não conhece I/O nem nós; `ObstacleManager` recebe o jogador como parâmetro de `update()` (padrão dos galões), não por referência guardada. **PASS**.
- **§IV Configuração** — todos os pesos da pontuação, desvio da poça e efeitos de cascalho, distribuição, caminhos de assets, formato do arquivo e limite de histórico entram como blocos novos no `game_config.gd` (FR-026). **PASS**.
- **§V Disciplina de Mudanças** — `gameplay.tscn` intocado; wiring por código no `_ready`/`_processar_playing`/`_avaliar_transicoes`; mudanças pontuais nos arquivos estendidos listados acima. **PASS**.
- **§VI pt-BR** — docstrings, comentários, nomes de identificadores e textos de UI em português; literais de usuário só em `GameConfig.ui_strings`. **PASS**.
- **§VII Performance** — pool pequena e fixa, 1 gravação por corrida, `ProgressManager` sem `_process`, histórico com teto configurável, sem alocação por quadro no caminho quente. **PASS**.
- **§VIII Testes** — cobertura automatizada de fórmula de pontuação, recordes por modo, ciclos de troféus, desbloqueio, I/O do save (caminho injetável), efeitos temporizados, spawn/validação e sondagem de 100 encontros em Desafio (SC-009). **PASS**.

*Re-check pós-design (Phase 1)*: nenhum gate violado — **Complexity Tracking fica vazio**.

## Project Structure

### Documentation (this feature)

```text
specs/011-records-trophies-obstacles/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 — decisões R1…R12
├── data-model.md        # Phase 1 — entidades, esquema de persistência, estados
├── quickstart.md        # Phase 1 — aceite manual + calibração
├── contracts/           # Phase 1
│   ├── progress_manager_api.md   # API do domínio de progressão/pontuação
│   ├── obstacle_integration.md   # Obstáculos × GameplayManager × VehicleController × GameConfig
│   └── ui_progress_display.md    # Métodos/strings da UI de progressão
├── checklists/
│   └── requirements.md  # 16/16 PASS (pré-existente)
└── tasks.md             # Phase 2 — /speckit.tasks (ainda não criado)
```

### Source Code (repository root)

```text
src/
├── config/
│   └── game_config.gd            # ESTENDER: blocos score_*, poca_*, cascalho_*,
│                                 # obstaculo_*, save_*, trofeu_assets, ui_strings novos
├── save/
│   ├── save_manager.gd           # NOVO: I/O JSON user:// (carregar/gravar, atômico)
│   └── (sem mais arquivos — I/O puro, RefCounted)
├── game/
│   ├── gameplay_manager.gd       # ESTENDER: campos + wiring + passo de obstáculos +
│                                 # ramo de encerramento (processar_vitoria/derrota + save 1×)
│   ├── progress_manager.gd       # NOVO: recordes, histórico, acumulados, troféus,
│                                 # ciclos, desbloqueio, calcular_pontuacao (RefCounted)
│   └── race_progression.gd       # intocado (lê ambiente_atual() antes de avançar)
├── obstacles/
│   ├── obstacle.gd               # NOVO: item do pool (poça/cascalho, área de ativação)
│   └── obstacle_manager.gd       # NOVO: pool, spawn por distância, validação, detecção
├── items/
│   └── fuel_can_manager.gd       # intocado (referência de padrão)
├── player/
│   ├── vehicle_controller.gd     # ESTENDER: efeito temporizado do cascalho (velocidade); poça sai (ajuste T032)
│   └── player_vehicle.gd         # intocado
├── fuel/
│   └── fuel_system.gd            # ESTENDER: acumulador perda_colisao_corrida + getter
└── ui/
    └── ui_manager.gd             # ESTENDER: painel de progresso no menu/vitória/game over

tests/unit/                       # ESTENDER: novas suítes ao lado das legadas
├── progress_manager_test.gd      # NOVO: recordes, ciclos, troféus, desbloqueio, acumulados
├── score_calculation_test.gd     # NOVO: fórmula FR-004…FR-008 (SC-002/SC-003)
├── save_manager_test.gd          # NOVO: round-trip, arquivo ausente/corrompido, atômico
├── progress_flow_test.gd         # NOVO: vitória/derrota/encerramento no orquestrador
├── obstacle_manager_test.gd      # NOVO: spawn, validação de limites/espacamento, gate
├── obstacle_effects_test.gd      # NOVO: efeitos no VehicleController, renovação, reset,
│                                 # congelamento e sonda de 100 encontros em Desafio (SC-009)
```

**Structure Decision**: mantém-se o layout em camadas já existente (`src/<domínio>/` + orquestração em `src/game/` + UI em `src/ui/`). `src/save/` nasce como o único módulo de I/O do projeto; `src/obstacles/` espelha `src/items/` (manager + item); o domínio de progressão/pontuação vive em `src/game/` ao lado de `race_progression.gd`, com quem já é dono do ciclo de vitória/derrota. Nenhum autoload novo (os únicos continuam `GameConfig`/`GameState`); nenhum nó novo em `gameplay.tscn`.
