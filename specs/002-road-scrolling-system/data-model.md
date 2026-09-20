# Data Model: Road Scrolling System

**Feature**: 002-road-scrolling-system
**Date**: 2026-09-18

## Entities

### Road

Gerencia o pool de segmentos, scrolling e reciclagem.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| segment_pool | Array[Node2D] | [] | pré-alocado | Pool de segmentos reutilizáveis |
| segment_types | Array[int] | [] | 0-3 | Tipo de cada segmento no pool (0=STRAIGHT, 1=EXPANSION, 2=REDUCTION, 3=EXPANDED) |
| scroll_speed | float | 0.0 | ≥ 0 | Velocidade atual de scrolling |
| scroll_offset | float | 0.0 | ≥ 0 | Offset total acumulado |
| screen_height | float | 480.0 | fixo | Altura da viewport |
| left_boundary | float | 248.0 | pixel_x | Limite esquerdo da estrada |
| right_boundary | float | 392.0 | pixel_x | Limite direito da estrada |
| segment_height | float | 192.0 | obtido do asset | Altura do segmento atual |
| segment_width | float | 144.0 | obtido do asset | Largura do segmento atual |
| pool_size | int | Calculado | ceil(screen_height/segment_height) + buffer | Tamanho do pool |

**Relationships**:
- Contém RoadSegment (composição)
- Referencia GameConfig (leitura de parâmetros)
- Referencia PlayerVehicle (leitura de velocidade)
- Calcula limites dinamicamente via get_boundaries_for_player_y() (não usa mais signal boundary_changed)

**State Transitions**:
- scroll_speed: 0 → max (via player_speed × multiplier)
- scroll_speed: max → 0 (via desaceleração)

**Methods**:
- `_process(delta)` — Atualizar scrolling e reciclar segmentos
- `_initialize_pool()` — Criar pool de segmentos (iniciando com offset -segment_height)
- `_recycle_segments()` — Reposicionar segmentos que saíram da tela (encontra menor y e posiciona acima)
- `_update_boundaries(type)` — Atualizar limites baseado no tipo do segmento
- `update_scroll_speed(player_speed)` — Atualizar velocidade de scrolling
- `add_segment(type)` — Adicionar segmento de um tipo específico
- `get_boundaries_for_player_y(player_y)` — Retornar limites laterais baseado na posição Y do jogador com interpolação trapezoidal

---

### RoadSegment

Representa um segmento individual da estrada.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| segment_type | Enum | STRAIGHT | STRAIGHT, EXPANSION, REDUCTION | Tipo do segmento |
| texture | Texture2D | null | asset_path | Textura do segmento |
| width | float | 0.0 | > 0 | Largura do segmento (obtida do asset) |
| height | float | 0.0 | > 0 | Altura do segmento (obtida do asset) |
| position | Vector2 | (0, 0) | pixel coordinates | Posição na tela |

**Enum Values**:
```text
SegmentType:
    STRAIGHT    # estrada_2_vias.png (2 vias)
    EXPANSION   # estrada_expansao_4_vias.png (2→4 vias)
    REDUCTION   # estrada_reducao_2_vias.png (4→2 vias)
```

**Relationships**:
- Pertence a Road (composição)
- Referencia GameConfig (leitura de limites)

**State Transitions**:
- position.y: 0 → screen_height + buffer → reposicionado acima

---

### GameConfig (Extensão para SPEC-002)

Parâmetros adicionais de scrolling.

| Field | Type | Default | Constraints | Description |
|-------|------|---------|-------------|-------------|
| scroll_multiplier | float | 1.0 | > 0 | Fator entre velocidade do jogador e scrolling |
| visible_segment_count | int | Calculado | > 0 | Quantidade de segmentos no pool |
| segment_buffer | int | 2 | ≥ 1 | Segmentos extras além dos visíveis |
| road_straight_path | String | "res://assets/estrada/estrada_2_vias.png" | asset_path | Caminho do segmento reto |
| road_expansion_path | String | "res://assets/estrada/estrada_expansao_4_vias.png" | asset_path | Caminho do segmento de expansão |
| road_reduction_path | String | "res://assets/estrada/estrada_reducao_2_vias.png" | asset_path | Caminho do segmento de redução |

**Access Pattern**: Somente leitura durante gameplay.

---

## Relationships Diagram

```
GameConfig (autoload)
    ↓ (leitura)
Road ←-------- RoadSegment
    ↓ (leitura)      ↓ (leitura)
PlayerVehicle ←-- VehicleController
```

## Validation Rules

1. **Velocidade**: scroll_speed ≥ 0 (sempre)
2. **Pool Size**: visible_segment_count = ceil(screen_height / segment_height) + segment_buffer
3. **Posição X**: segment.position.x = left_boundary (alinhamento pela esquerda, centered = false)
4. **Reciclagem**: segment.position.y > screen_height + segment_height → reposicionar acima do segmento com menor y
5. **Limites**: (left_boundary + half_width) ≤ player_x ≤ (right_boundary - half_width) (sempre)
6. **Assets**: fallback para placeholder se asset não encontrado
7. **Sincronização**: gameplay_manager chama get_boundaries_for_player_y() a cada frame para atualizar limites do VehicleController
8. **Inicialização**: segmentos iniciam com offset -segment_height para garantir cobertura acima da tela
9. **Interpolação**: t = 1.0 - (player_y - seg_top) / segment_height (inverso porque segmento chega pelo bottom primeiro)
10. **Trapezoidal**: EXPANSION interpola narrow→wide, REDUCTION interpola wide→narrow

## State Transitions

### Road States

```text
IDLE (speed = 0)
    ↓ (player_speed > 0)
SCROLLING (speed > 0)
    ↓ (player_speed = 0)
DECELERATING (speed > 0, decreasing)
    ↓ (speed = 0)
IDLE
```

### Segment Recycling

```text
ACTIVE (y < screen_height + buffer)
    ↓ (y > screen_height + buffer)
RECYCLING (reposicionar acima da tela)
    ↓ (position updated)
ACTIVE
```
