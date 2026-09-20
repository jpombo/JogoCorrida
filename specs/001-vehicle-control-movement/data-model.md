# Data Model: Vehicle Control and Movement

**Feature**: 001-vehicle-control-movement
**Date**: 2026-09-18

## Entities

### PlayerVehicle

Representa o veículo do jogador — sprite, collision shape, estado físico.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| sprite | Sprite2D | azul.png | asset_path: String | Representação visual do veículo |
| collision_shape | CollisionShape2D | Rectangle | width, height fixos | Forma de colisão para limites |
| position | Vector2 | (center_x, 85%) | x ∈ [road_left, road_right], y ∈ [y_min, y_max] | Posição na tela |
| speed | float | 0.0 | 0.0 ≤ speed ≤ max_speed | Velocidade atual (vertical) |
| lateral_speed | float | 0.0 | -lateral_max ≤ lat ≤ +lateral_max | Velocidade lateral atual |
| is_accelerating | bool | false | — | Se accelerate está ativo |
| is_braking | bool | false | — | Se brake está ativo |
| is_moving_left | bool | false | — | Se move_left está ativo |
| is_moving_right | bool | false | — | Se move_right está ativo |

**Relationships**:
- Possui VehicleController (composição)
- Referencia GameConfig (leitura de parâmetros)
- Referencia Road (leitura de limites)

**State Transitions**:
-speed: 0 → max_speed (via accelerate) → 0 (via brake/inércia)
- lateral_speed: 0 → ±lateral_max (via move_left/right) → 0 (desaceleração)

---

### VehicleController

Gerencia lógica de controle — lê inputs, calcula aceleração/frenagem/desaceleração/movimento.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| speed | float | 0.0 | 0.0 ≤ speed ≤ max_speed | Velocidade atual do veículo |
| lateral_speed | float | 0.0 | -lateral_max ≤ lat ≤ +lateral_max | Velocidade lateral atual |
| current_left_boundary | float | 248.0 | pixel_x | Limite esquerdo atual da estrada |
| current_right_boundary | float | 392.0 | pixel_x | Limite direito atual da estrada |

**Responsibilities**:
- Ler inputs do sistema Input Map
- Calcular mudanças de velocidade (aceleração, frenagem, inércia)
- Calcular movimento lateral
- Aplicar limites dinâmicos da estrada (atualizados via update_boundaries)
- Atualizar estado do PlayerVehicle

**Methods**:
- `_process(delta: float)` — Processar inputs e atualizar física
- `_apply_vertical_physics(delta: float)` — Calcular velocidade vertical
- `_apply_lateral_physics(delta: float)` — Calcular velocidade lateral
- `_clamp_position(current_x: float)` — Respeitar limites dinâmicos da estrada
- `update_boundaries(left: float, right: float)` — Atualizar limites laterais (chamado quando pista muda de tipo)
- `get_vertical_position() -> float` — Retornar posição Y normalizada baseada na velocidade
- `get_horizontal_direction() -> float` — Retornar direção lateral (-1.0, 0.0, 1.0)
- `reset()` — Resetar estado para valores iniciais

---

### Road

Representa a estrada — área válida, limites laterais, preparação para scrolling.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| left_boundary | float | 248.0 | pixel_x | Limite esquerdo da estrada |
| right_boundary | float | 392.0 | pixel_x | Limite direito da estrada |
| top_boundary | float | 0.0 | pixel_y | Limite superior (scrolling futuro) |
| bottom_boundary | float | 600.0 | pixel_y | Limite inferior |
| road_width | float | 144.0 | Calculado: right - left | Largura da faixa de rodagem |
| scroll_offset | float | 0.0 | ≥ 0 | Offset de scrolling (futuro) |

**Relationships**:
- Referenciado por PlayerVehicle (para limites)
- Será estendido por RoadManager (scrolling futuro - SPEC 002)

**State Transitions**:
- scroll_offset: 0 → ∞ (via scrolling futuro)

---

### GameState

Estado global do jogo — controla transições de tela.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| current_state | State | MENU | enum: MENU, READY, PLAYING, PAUSED, VICTORY, GAME_OVER | Estado atual |
| previous_state | State | MENU | enum | Estado anterior (para transições) |

**State Transitions**:
```
MENU → READY (quando jogador inicia)
READY → PLAYING (após countdown/pronto)
PLAYING → PAUSED (quando pausa)
PAUSED → PLAYING (quando retoma)
PLAYING → GAME_OVER (colisão/fuel - futuro)
PLAYING → VICTORY (atinge finish - futuro)
```

**Relationships**:
- Controlado por GameManager (central)
- Observado por PlayerVehicle, UI (futuro)

---

### GameConfig (Autoload Singleton)

Parâmetros centralizados de configuração — apenas leitura durante gameplay.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| max_speed | float | 100.0 | > 0 | Velocidade máxima do veículo |
| acceleration | float | 40.0 | > 0 | Taxa de aceleração |
| brake_force | float | 70.0 | > 0 | Taxa de frenagem |
| natural_deceleration | float | 15.0 | > 0 | Taxa de desaceleração natural |
| lateral_speed | float | 100.0 | > 0 | Velocidade lateral máxima |
| lateral_acceleration | float | 300.0 | > 0 | Taxa de aceleração lateral |
| lateral_deceleration | float | 400.0 | > 0 | Taxa de desaceleração lateral |
| initial_vertical_position | float | 0.95 | 0.0-1.0 | Posição Y inicial (% da tela) — base do carro alinhada com margem |
| vertical_position_min | float | 0.60 | 0.0-1.0 | Posição Y mínima (velocidade máxima) — 1 carro abaixo do meio |
| vertical_position_max | float | 0.95 | 0.0-1.0 | Posição Y máxima (parado) — base com margem de segurança |
| road_left_boundary | float | 248.0 | pixels | Limite esquerdo da estrada |
| road_right_boundary | float | 392.0 | pixels | Limite direito da estrada |
| target_fps | int | 60 | > 0 | Framerate alvo |

**Access Pattern**: Somente leitura durante gameplay. Valores podem ser alterados via editor ou config files antes de iniciar.

---

## Relationships Diagram

```
GameConfig (autoload)
    ↓ (leitura)
PlayerVehicle ←-------- VehicleController
    ↓ (leitura)              ↓ (leitura)
Road ←---------------- Road (limites)
    ↓
GameState (observa)
```

## Validation Rules

1. **Velocidade**: 0 ≤ speed ≤ max_speed (sempre)
2. **Posição X**: (road_left_boundary + half_width) ≤ x ≤ (road_right_boundary - half_width), onde half_width = 16px
3. **Posição Y**: vertical_position_min ≤ y ≤ vertical_position_max
4. **Simultaneidade**: brake prevalece sobre accelerate (FR-005A)
5. **Diagonal**: velocidade total ≤ soma dos componentes (normalização)
6. **Assets**: fallback para placeholder se sprite não encontrado
7. **Limites Dinâmicos**: VehicleController atualiza limites via update_boundaries() quando pista muda de tipo
