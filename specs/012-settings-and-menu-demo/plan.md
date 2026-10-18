# Implementation Plan: Menu de Configurações Aprimorado e Menu Principal Dinâmico

**Branch**: `012-settings-and-menu-demo` | **Date**: 2026-10-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/012-settings-and-menu-demo/spec.md`

## Summary

A SPEC-012 adiciona ao JogoCorrida (Godot 4.7, GDScript, pt-BR) duas entregas na experiência inicial: (A) um **menu de configurações** — que hoje não existe — com controle geral de áudio ligado/desligado e seleção de resolução de janela (640 × 480 / 1024 × 768, tamanho fixo), aplicadas imediatamente e persistidas em `user://preferencias.json`; e (B) uma **demonstração automática de gameplay no menu principal** — estrada rolando, fundo e decoração do ambiente, 2–4 NPCs reutilizando `TrafficVehicle`, ciclo contínuo Planície → Deserto → Floresta → Gelo com *fade* de escurecimento/clareamento — totalmente isolada do gameplay real (sem jogador, sem combustível/pontuação/recordes/troféus, sem áudio, sem tocar em `GameConfig.current_environment_id` ou nos multiplicadores da SPEC-009). O approach segue os padrões consolidados nas SPEC-007…011: componentes novos instanciados em código pelo `GameplayManager` (nenhum autoload novo, `gameplay.tscn` intocado), `RefCounted` para lógica pura com I/O delegado ao `SaveManager` já existente (caminho injetável), textos 100% via `GameConfig.ui_strings`, todos os números novos no `GameConfig`, guards nulos nos campos novos para preservar os 478 testes legados, e cobertura automatizada da lógica determinística exigida pela constituição (ciclo de ambientes, validação de preferências, limite/reciclagem de NPCs da demonstração).

## Technical Context

**Language/Version**: GDScript, Godot 4.7.2 (binário `Godot_v4.7.2-stable_linux.x86_64`, `config/features=PackedStringArray("4.7")`); cena principal `res://src/game/gameplay.tscn` (única `.tscn` do projeto — telas são construídas em código).

**Primary Dependencies**: Engine Godot apenas (sem plugins novos); GdUnit4 já presente em `addons/gdUnit4/`; componentes visuais reutilizados da engine/código existente: `Road`, `BackgroundController`, `DecorationManager`, `TrafficVehicle`, `AudioServer` (bus Master), `DisplayServer` (tamanho/janela) — nenhum asset novo a criar.

**Storage**: Preferências em JSON em `user://preferencias.json`, **gravado pelo próprio `SaveManager`** já existente (`src/save/save_manager.gd` — caminho injetável no construtor, escrita atômica tmp+rename, carregamento tolerante). Domínio/validação em novo `PreferencesManager` (`RefCounted`). Arquivo separado do progresso (`user://progresso.json`) — Clarificação Q1 da spec.

**Testing**: GdUnit4 em `tests/unit/` (suíte completa hoje: **74 suítes / 478 casos**, exit 101); novas suítes `preferences_manager_test`, `menu_demo_test`, `settings_menu_test`, `audio_settings_test`; `DisplayServer`/`AudioServer` são seguros em `--headless` (dummy driver — aplicação de resolução protegida por guarda headless **e por `Engine.is_embedded_in_editor()` na janela embutida do editor**, mut de bus funciona).

**Target Platform**: Desktop Godot (viewport base fixo 640 × 480, `stretch/mode="viewport"`, aspecto default `keep`; janela 4:3); suíte roda em `--headless`.

**Project Type**: Jogo 2D single-player; orquestração por `GameplayManager` (`src/game/gameplay_manager.gd`, 742 linhas).

**Performance Goals**: 60 fps; demonstração com pool fixa de NPCs (≤ `demo_npc_max = 4`), um `Tween` curto por transição (≤ 2 s), zero `_process` novo no `AudioManager`/`SaveManager`/`PreferencesManager`, sem alocação por quadro no caminho quente da demo.

**Constraints**: Suíte legada de 478 casos 100% verde — **salvo a única adaptação intencional de `difficulty_menu_selector_test.gd`** prevista no T007 do tasks.md (menu de 3 → 4 linhas; precedente: a SPEC-009 já ajustou essa mesma suíte); nenhuma mudança nos multiplicadores da SPEC-009; demonstração silenciosa (sem forwards de áudio); janela não redimensionável livremente (Clarificação Q2); textos 100% via `GameConfig.ui_strings` (§VI); configurações acessíveis só pelo menu principal (Clarificação Q4).

**Scale/Scope**: ~2 arquivos-fonte novos (`preferences_manager.gd`, `menu_demo.gd`), ~4 estendidos (`ui_manager.gd`, `gameplay_manager.gd`, `audio_manager.gd`, `game_config.gd`), 1 ajuste declarativo em `project.godot` (`window/size/resizable=false`), ~4 suítes novas; nenhum sistema legado reescrito.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **§I Controles simples / III Modularidade** — dois módulos novos com responsabilidade única: `src/config/preferences_manager.gd` (domínio+validação de preferências; I/O delegado) e `src/menu/menu_demo.gd` (ciclo de vida da demonstração visual). Comunicação por sinais/orquestração no padrão existente (UI → `GameplayManager` → componentes). **PASS**.
- **§II Experiência do jogador** — mudanças de UI seguem o fluxo já aprovado (índice + `wrapi` + destaque); demonstração e configurações nunca bloqueiam a navegação; legibilidade garantida por véu semitransparente configurável atrás dos textos. **PASS**.
- **§IV Design orientado a configuração** — todos os números novos (duração do ambiente, durações do fade, contagem/intervalo/velocidade dos NPCs, resoluções válidas e padrões, arquivo de preferências, alpha do véu) vivem no `GameConfig` (FR-022). **PASS**.
- **§V Autoridade/escopo** — sem tela cheia, sem remapeamento, sem volume por categoria, sem sons novos, sem menu paralelo, sem corrida em segundo plano; nenhum estado novo no `GameState` (MENU/READY/PLAYING/PAUSED/VICTORY/GAME_OVER intactos). **PASS**.
- **§VI pt-BR** — docstrings/comentários/identificadores em português; literais de usuário só em `ui_strings` (chaves novas `settings`, `settings_title`, `audio_label`, …). **PASS**.
- **§VIII Testes** — cobertura automatizada de spawn/reciclagem/seleção: ciclo e ordem dos ambientes da demo, validação/carregamento/recuperação de preferências, limite/reciclagem de NPCs, mute central de áudio e navegação do painel de configurações (Clarificação Q3). **PASS**.
- **§Performance/Assets** — pool fixa reutilizando `TrafficVehicle` (sprites/texture-cache existentes), fundo/decoração/estrada reutilizando as classes atuais, demo deixa de processar fora do MENU; lógica independente de sprite específico (caminhos via `GameConfig`). **PASS**.

*Re-check pós-design (Phase 1)*: nenhum gate violado — **Complexity Tracking fica vazio**.

## Project Structure

### Documentation (this feature)

```text
specs/012-settings-and-menu-demo/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 — decisões R1…R9
├── data-model.md        # Phase 1 — preferências, estados da demonstração, parâmetros
├── quickstart.md        # Phase 1 — aceite manual + calibração
├── contracts/           # Phase 1
│   ├── preferences_manager_api.md  # API do domínio de preferências (+ SaveManager par)
│   ├── menu_demo_lifecycle.md      # API/ciclo de vida da demonstração do menu
│   └── settings_menu_commands.md   # Painel de configurações: navegação, strings, sinais
├── checklists/
│   └── requirements.md  # 16/16 PASS (pré-existente)
└── tasks.md             # Phase 2 — /speckit.tasks (ainda não criado)
```

### Source Code (repository root)

```text
src/
├── config/
│   ├── game_config.gd            # ESTENDER: blocos preferencias_* e demo_* +
│   │                             #        chaves novas de ui_strings (SPEC-012)
│   └── preferences_manager.gd    # NOVO: domínio+validação das preferências (RefCounted);
│                                 #        I/O via SaveManager com caminho injetável
├── menu/
│   └── menu_demo.gd              # NOVO: demonstração do menu (Node2D) — cria em código
│                                 #        Road + BackgroundController + DecorationManager
│                                 #        próprios, pool fixa de TrafficVehicle e fade
├── audio/
│   └── audio_manager.gd          # ESTENDER: set_geral_ativo()/geral_ativo() — mute do
│                                 #        bus Master via AudioServer (central, RF-001)
├── ui/
│   └── ui_manager.gd             # ESTENDER: painel de configurações (áudio/resolução),
│                                 #        linha "Configurações" no menu, véu de
│                                 #        legibilidade e sinais de settings/demo
├── game/
│   └── gameplay_manager.gd       # ESTENDER: campos preferencias/menu_demo + wiring no
│                                 #        _ready/_show_* (iniciar/pausar/encerrar demo,
│                                 #        aplicar preferências, salvar ao alterar)
└── save/
    └── save_manager.gd           # intocado (reutilizado com caminho user://preferencias.json)

project.godot                      # AJUSTE: window/size/resizable=false (janela fixa)

tests/unit/                        # ESTENDER: novas suítes ao lado das legadas
├── preferences_manager_test.gd    # NOVO: round-trip, ausente/corrompido, validação e
│                                  #        recuperação parcial, defaults (SC-002/SC-003)
├── menu_demo_test.gd              # NOVO: ordem do ciclo, duração configurável, fade
│                                  #        cancelado sem tela escura, limite/reciclagem
│                                  #        e reinício sem acúmulo de NPCs (SC-004…SC-007)
├── settings_menu_test.gd          # NOVO: navegação do painel, sinais de alteração,
│                                  #        cancel volta ao menu, pausa/retoma da demo
└── audio_settings_test.gd         # NOVO: set_geral_ativo ⇒ bus Master mudo/restaurado
                                  #        e idempotência (SC-001)
```

**Structure Decision**: mantém-se o layout em camadas já existente (`src/<domínio>/` + orquestração em `src/game/` + UI em `src/ui/`). `src/config/` recebe o domínio de preferências ao lado do `game_config.gd` (que é o dono dos defaults/validos); `src/menu/` nasce como o módulo da demonstração do menu (espelha a ideia de `src/environment/` e `src/decoration/`: componente visual reutilizável, sem gameplay). Nenhum autoload novo (os únicos continuam `GameConfig`/`GameState`); nenhum nó novo em `gameplay.tscn` — o `MenuDemo` e o painel de configurações são criados em código, no padrão já usado pelas telas do `UIManager`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(vazio — nenhum gate da constituição violado)* | — | — |
