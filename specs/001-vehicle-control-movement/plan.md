# Implementation Plan: Vehicle Control and Movement

**Branch**: `001-vehicle-control-movement` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-vehicle-control-movement/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Implementação do sistema core de movimento do veículo do jogador em jogo de corrida 2D top-down arcade. O sistema inclui: controle de 4 ações (acelerar, frear, mover esquerda/direita), física arcade com aceleração/frenagem progressiva, inércia, movimento diagonal, limites de estrada, e sprite configurável. A câmera mantém veículo fixo na tela enquanto a estrada rola verticalmente.

## Technical Context

**Language/Version**: GDScript (Godot 4.x) — engine 2D com sistema de Input, sprites, e física arcade

**Primary Dependencies**: Godot Engine 4.x (não requer dependências externas adicionais)

**Storage**: N/A (estado em memória durante gameplay)

**Testing**: GdUnit4 ou testes manuais via debug — engine suporta testes determinísticos para lógica de posição/velocidade

**Target Platform**: Desktop (Windows, Linux, macOS) — pixel art 2D, 60 FPS

**Project Type**: Game (2D arcade racing)

**Performance Goals**: 60 FPS estável, < 2s tempo de carregamento inicial

**Constraints**: Top-down 2D, pixel art, controles fixos (WASD/setas), sem física realista

**Scale/Scope**: Fase 1 — Core Movement (1 jogador, 1 veículo, estrada estática com preparação para scrolling futuro)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Verificação de Consistência com a Constituição

| Princípio | Status | Observação |
|-----------|--------|------------|
| I. Simple Controls, Deep Gameplay | ✅ PASS | 4 controles básicos, sem complexidade desnecessária |
| II. Player Experience Priority | ✅ PASS | Física responsiva e previsível priorizada |
| III. Modular Architecture | ✅ PASS | PlayerVehicle, VehicleController, Road separados (FR-020) |
| IV. Configuration-Driven Design | ✅ PASS | Parâmetros centralizados (FR-021, FR-022) |
| V. Scope Protection | ✅ PASS | Sem armas, multiplayer, RPG — apenas core movement |
| VI. Multilingual Support | ✅ PASS | Documentação em PT-BR, jogo suporta en-US + pt-BR |
| Asset Independence | ✅ PASS | Sprite trocável sem alterar física (FR-018) |
| Game State | ✅ PASS | Fluxo MENU→READY→PLAYING definido (FR-023) |
| Camera/Presentation | ✅ PASS | Top-down 2D, veículo fixo, estrada rola (FR-026, FR-027) |

**GATE RESULT**: ✅ PASS — Nenhuma violação detectada. Todos os princípios da constituição são atendidos pela especificação.

## Project Structure

### Documentation (this feature)

```text
specs/001-vehicle-control-movement/
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
├── player/
│   ├── player_vehicle.gd      # Representação: sprite, collision, estado
│   └── vehicle_controller.gd  # Lógica: input, aceleração, frenagem, movimento
├── road/
│   └── road.gd                # Estrada: limites, área válida, preparação scrolling
├── game/
│   └── game_state.gd          # Estado global: MENU, READY, PLAYING, etc.
└── config/
    └── game_config.gd         # Parâmetros centralizados (autoload)

assets/
├── player/
│   ├── azul/
│   │   └── azul.png           # Sprite padrão
│   └── vermelho/
│       └── vermelho.png       # Sprite alternativo
└── estrada/                   # Assets da estrada (existentes)

tests/
└── unit/
    ├── test_vehicle_physics.gd
    └── test_road_boundaries.gd
```

**Structure Decision**: Estrutura modular seguindo constituição (Princípio III). Separção clara entre representação (player_vehicle.gd), lógica (vehicle_controller.gd), e infraestrutura (road.gd, game_state.gd). Config centralizado em autoload para parâmetros configuráveis.

## Complexity Tracking

> **Sem violações da constituição — seção não aplicável**
