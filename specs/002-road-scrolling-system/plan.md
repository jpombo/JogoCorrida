# Implementation Plan: Road Scrolling System

**Branch**: `002-road-scrolling-system` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-road-scrolling-system/spec.md`

## Summary

Implementar o sistema visual de estrada com scrolling vertical baseado na velocidade do jogador, utilizando um pool de segmentos reutilizáveis para criar a sensação de deslocamento contínuo. O sistema suporta segmentos retos e transições de largura (expansão/redução), com limites dinâmicos baseados na posição Y do jogador using trapezoidal interpolation e fallback visual para assets ausentes.

## Technical Context

**Language/Version**: GDScript (Godot 4.x)

**Primary Dependencies**: Godot Engine 4.x, Sprite2D nodes, Node2D hierarchy

**Storage**: N/A (runtime state only)

**Testing**: GdUnit4 (unit tests), validação visual manual

**Target Platform**: Desktop (Linux, Windows, macOS) — 640x480 viewport

**Project Type**: 2D arcade racing game

**Performance Goals**: 60 FPS estável durante scrolling contínuo

**Constraints**: Pixel-art rendering (no smoothing), pool de segmentos pré-alocados

**Scale/Scope**: 1 feature branch, ~5-8 scripts, 3 assets de estrada

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Simple Controls | ✅ PASS | Scrolling é visual, não adiciona controles |
| II. Player Experience | ✅ PASS | Scrolling reforça sensação de velocidade |
| III. Modular Architecture | ✅ PASS | Road separado de PlayerVehicle e VehicleController |
| IV. Configuration-Driven | ✅ PASS | scroll_multiplier, visible_segment_count configuráveis |
| V. Scope Protection | ✅ PASS | Não implementa progressão lógica da pista |
| VI. Multilingual | ✅ PASS | Documentação em PT-BR |
| Asset Independence | ✅ PASS | Lógica não depende de assets específicos |
| Performance | ✅ PASS | Pool reutiliza objetos, sem criação por frame |

**Resultado**: Todos os gates PASSaram. Violações: Nenhuma.

## Project Structure

### Documentation (this feature)

```text
specs/002-road-scrolling-system/
├── plan.md              # Este arquivo
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── config/
│   └── game_config.gd      # Parâmetros configuráveis (scroll_multiplier, etc.)
├── game/
│   ├── game_state.gd       # Autoload de estados
│   ├── gameplay_manager.gd # Integra Road + PlayerVehicle
│   └── gameplay.tscn       # Cena principal
├── player/
│   ├── player_vehicle.gd   # Veículo do jogador
│   └── vehicle_controller.gd # Física e inputs
└── road/
    ├── road.gd             # Gerencia pool de segmentos, scrolling
    └── road_segment.gd     # Segmento individual (Sprite2D + lógica)
```

**Structure Decision**: Estrutura modular existente do SPEC-001. Adicionados `road.gd` (refatorado) e `road_segment.gd` (novo).

## Complexity Tracking

> Nenhuma violação da constituição — seção não aplicável.
