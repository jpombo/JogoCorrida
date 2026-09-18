# Research: Vehicle Control and Movement

**Feature**: 001-vehicle-control-movement
**Date**: 2026-09-18

## Unknowns Identified

1. Engine selection and GDScript patterns for input handling
2. Arcade physics implementation in Godot 4.x
3. Camera setup for top-down scrolling road
4. Configuration management (autoload, resources)
5. Testing framework for GDScript

## Research Findings

### 1. Input Handling in Godot 4.x

**Decision**: Usar sistema de Input Map do Godot com ações lógicas

**Rationale**: Godot possui sistema integrado de Input Map que permite mapear teclas físicas para ações lógicas (ex: "accelerate", "brake"). Alinhado com FR-003 (não depender de teclas físicas diretamente).

**Alternatives considered**:
- Input direto via `Input.is_key_pressed()` — rejeitado por violar FR-003
- Sistema customizado de input — desnecessariamente complexo para fase 1

**Implementation pattern**:
```gdscript
# No project.godot ou via código:
# Input Map: accelerate → W/↑, brake → S/↓, move_left → A/←, move_right → D/→

func _process(delta):
    if Input.is_action_pressed("accelerate"):
        # acelerar
    if Input.is_action_pressed("brake"):
        # frear
```

### 2. Arcade Physics in Godot 4.x

**Decision**: Física customizada em GDScript (não usar CharacterBody2D com move_and_slide para física vertical)

**Rationale**: O movimento vertical é baseado em velocidade (posição = f(velocidade)), não em física realista. CharacterBody2D é ideal para movimento lateral (colisão com limites), mas a física vertical deve ser calculada diretamente.

**Alternatives considered**:
- RigidBody2D — rejeitado por ser baseado em física realista (viola constituição)
- CharacterBody2D para tudo — viável, mas cálculo de posição vertical manual é mais simples
- KinematicBody2D — deprecated em Godot 4

**Implementation pattern**:
```gdscript
# vehicle_controller.gd
var speed: float = 0.0
var lateral_speed: float = 0.0

func _process(delta):
    # Física vertical (baseada em velocidade)
    if Input.is_action_pressed("accelerate"):
        speed = min(speed + acceleration * delta, max_speed)
    elif Input.is_action_pressed("brake"):
        speed = max(speed - brake_force * delta, 0.0)
    else:
        speed = max(speed - natural_deceleration * delta, 0.0)
    
    # Física lateral (independente)
    if Input.is_action_pressed("move_left"):
        lateral_speed = max(lateral_speed - lateral_acceleration * delta, -lateral_speed_max)
    elif Input.is_action_pressed("move_right"):
        lateral_speed = min(lateral_speed + lateral_acceleration * delta, lateral_speed_max)
    else:
        # Desaceleração lateral
        if lateral_speed > 0:
            lateral_speed = max(lateral_speed - lateral_deceleration * delta, 0.0)
        else:
            lateral_speed = min(lateral_speed + lateral_deceleration * delta, 0.0)
```

### 3. Camera Setup for Top-Down Scrolling

**Decision**: Câmera fixa no veículo, estrada rola verticalmente via shader ou movimento de tilemap

**Rationale**: FR-027 especifica veículo fixo na tela, estrada rola. Isso simplifica câmera (não precisa de smoothing) e cria sensação de velocidade.

**Alternatives considered**:
- Câmera seguindo veículo com smoothing — rejeitado por FR-027
- Câmera estática + veículo move — viável, mas menos comum para corrida
- Parallax scrolling — para background, não para estrada principal

**Implementation pattern**:
```gdscript
# road.gd
@export var scroll_speed: float = 100.0

func _process(delta):
    # Mover tilemap/estrada para baixo conforme velocidade do jogador
    position.y += scroll_speed * delta
    # Resetar posição quando atinge fim do tile (loop infinito)
```

### 4. Configuration Management

**Decision**: Usar autoload singleton (GameConfig) com export de variáveis

**Rationale**: Godot suporta autoload para globals. Config centralizada permite balancing sem modificar código (FR-021, Princípio IV da constituição).

**Alternatives considered**:
- Resource files (.tres) — viável, mas autoload é mais simples para globals
- JSON/config files — mais complexo, desnecessário para fase 1
- Export vars no player_vehicle.gd — viola separação de responsabilidades

**Implementation pattern**:
```gdscript
# game_config.gd (autoload)
extends Node

# Física do veículo
@export var max_speed: float = 100.0
@export var acceleration: float = 40.0
@export var brake_force: float = 70.0
@export var natural_deceleration: float = 15.0
@export var lateral_speed: float = 100.0
@export var lateral_acceleration: float = 300.0
@export var lateral_deceleration: float = 400.0

# Posição vertical
@export var initial_vertical_position: float = 0.95  # Inicia na base da tela
@export var vertical_position_min: float = 0.60  # Topo: 1 tamanho do carro abaixo do meio
@export var vertical_position_max: float = 0.95  # Base: fundo da tela

# Limites da estrada
@export var road_left_boundary: float = 100.0
@export var road_right_boundary: float = 540.0
```

### 5. Testing Framework

**Decision**: GdUnit4 para testes unitários + testes manuais via debug

**Rationale**: GdUnit4 é framework de testes maduro para Godot 4. Permite testes determinísticos de lógica de física (SC-011).

**Alternatives considered**:
- Testes manuais apenas — insuficiente para validação automatizada
- GUT (Godot Unit Test) — alternativa viável, mas GdUnit4 mais ativo
- Testes integrados do Godot — limitados para lógica customizada

**Implementation pattern**:
```gdscript
# test_vehicle_physics.gd
extends GutTest

func test_speed_increases_with_acceleration():
    var controller = VehicleController.new()
    controller._process(0.1) # 100ms
    assert_gt(controller.speed, 0.0)

func test_speed_clamped_at_max():
    var controller = VehicleController.new()
    controller.speed = 99.0
    controller._process(1.0) # suficiente para exceder max
    assert_eq(controller.speed, GameConfig.max_speed)
```

## Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Input System | Godot Input Map | Simples, alinhado com FR-003 |
| Physics Engine | Custom GDScript | Arcade, não realista (constituição) |
| Camera | Fixa no veículo | FR-027, simplifica implementação |
| Configuration | Autoload singleton | Centralizado, configurável (FR-021) |
| Testing | GdUnit4 | Maduro, suporta testes determinísticos |
| Architecture | Modular (3 scripts) | PlayerVehicle, VehicleController, Road |

## Open Questions

- Nenhum — todos os unknowns foram resolvidos via pesquisa
