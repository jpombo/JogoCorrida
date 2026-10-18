# Implementation Plan: Sistema de Ambientes e Cenários

**Branch**: `003-environment-scenarios` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-environment-scenarios/spec.md`

## Summary

Implementar o sistema de ambientes visuais do jogo, introduzindo quatro ambientes (PLAINS, DESERT, FOREST, ICE) com backgrounds seamless, scroll sincronizado com a estrada e configuração centralizada. O sistema deve renderizar o background abaixo da estrada, repetindo texturas verticalmente para preencher a tela, com velocidade derivada do scrolling da estrada e multiplicador global configurável.

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7)

**Primary Dependencies**: Godot Engine 4.7 (rendering: gl_compatibility, viewport: 640x480, stretch mode: viewport, texture filter: nearest-neighbor)

**Storage**: N/A (configuração em autoload GameConfig, sem persistência externa)

**Testing**: GdUnit4 addon (já instalado em `addons/gdUnit4/`)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down perspective)

**Performance Goals**: Sem meta formal de FPS — verificar ausência de queda perceptível durante implementação

**Constraints**: Preservar pixel art (sem suavização, sem filtros, sem escalas fracionárias); viewport 640x480; renderização em camadas (Background → Estrada → Veículo). **Ajuste (2026-09-23)**: assets de background redimensionados para 640x480 renderizados em escala nativa 1:1 com filtro NEAREST.

**Scale/Scope**: 4 ambientes, 4 texturas seamless, 1 multiplicador global, sistema preparado para parallax futuro e modificadores por ambiente

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Simple Controls | ✅ PASS | Controles do jogador inalterados; background não introduz novos controles |
| II. Player Experience Priority | ✅ PASS | Background melhora experiência visual sem comprometer gameplay |
| III. Modular Architecture | ✅ PASS | Novo sistema (EnvironmentManager) com responsabilidade separada; não modifica Road, PlayerVehicle, nem VehicleController |
| IV. Configuration-Driven | ✅ PASS | Ambientes definidos como dicionário centralizado em GameConfig; background_multiplier configurável |
| V. Scope Protection | ✅ PASS | Feature dentro do escopo; não introduce armas, multiplayer, RPG, etc. |
| VI. Multilingual Support | ✅ PASS | Nomes exibidos em PT-BR (Planície, Deserto, Floresta, Gelo); documentação em PT-BR |
| Camera/Presentation | ✅ PASS | Background respeita pixel art; renderização abaixo da estrada; ordem correta |
| Asset Independence | ✅ PASS | Lógica de ambiente não depende de nomes de arquivos; assets referenciados por configuração |
| Performance | ✅ PASS | Sem otimização prematura; sem criação desnecessária de objetos por frame |
| Code Quality | ✅ PASS | Código descritivo; sem magic numbers; responsabilidade separada |

**Resultado: Todos os gates PASS. Sem violações a justificar.**

## Project Structure

### Documentation (this feature)

```text
specs/003-environment-scenarios/
├── spec.md              # Especificação da feature
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── config/
│   └── game_config.gd         # Adicionar:Environment, background_multiplier, background_scroll_speed
├── game/
│   ├── gameplay.tscn           # Adicionar: BackgroundLayer (Node2D) como primeiro filho
│   └── gameplay_manager.gd     # Adicionar: referência ao BackgroundLayer, sincronização de scroll
├── environment/
│   ├── environment_data.gd     # NOVO: Resource de dados do ambiente (ID, nome, asset, dificuldade)
│   ├── environment_manager.gd  # NOVO: Gerencia ambiente atual, seleção,提供 dificuldade
│   └── background_controller.gd# NOVO: Renderização, repetição seamless, scrolling vertical
├── player/
│   ├── player_vehicle.gd       # Sem alterações
│   └── vehicle_controller.gd   # Sem alterações
└── road/
    ├── road.gd                 # Sem alterações (scroll continua gerenciado por gameplay_manager)
    └── road_segment.gd         # Sem alterações

assets/
├── background/
│   ├── Seamless Pixel Art Grass Texture.png    # PLAINS
│   ├── Pixel Art Desert Sand Texture.png       # DESERT
│   ├── Pixel Art Forest Floor Texture.png      # FOREST
│   └── Pixel Art Snowy Ice Texture.png         # ICE
```

**Structure Decision**: Adotada a estrutura existente do projeto. Novos scripts em `src/environment/`. Background inserido como camada (Node2D) no scene tree de `gameplay.tscn`, antes da Road na ordem de renderização. Configuração adicionada ao existente `GameConfig` autoload.

## Complexity Tracking

Sem violações de constituição — seção não aplicável.
