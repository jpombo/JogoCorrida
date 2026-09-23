# Data Model: Sistema de Ambientes e Cenários

**Feature**: SPEC-003 — Environment Scenarios
**Date**: 2026-09-23

## Entities

### EnvironmentData

Representa a configuração de um ambiente individual. Dados estáticos, imutáveis após definição.

| Campo | Tipo | Descrição | Valores Válidos |
|-------|------|-----------|-----------------|
| `id` | String | Identificador lógico único | "PLAINS", "DESERT", "FOREST", "ICE" |
| `display_name` | String | Nome exibido ao jogador | "Planície", "Deserto", "Floresta", "Gelo" |
| `texture_path` | String | Caminho do asset de background | Caminho Godot (res://...) |
| `difficulty` | int | Nível de dificuldade base | 1, 2, 3, 4 |

**Restrições**:
- `id` deve ser único entre todos os ambientes
- `difficulty` deve ser ≥ 1
- `texture_path` deve referenciar um asset válido (fallback para PLAINS se inválido)

**Relationships**:
- Um `EnvironmentData` é associado a zero ou uma `LevelConfig` (configuração de nível)

---

### EnvironmentManager (Singleton/Manager)

Gerencia o ambiente atual e fornece acesso aos dados.

| Propriedade | Tipo | Descrição |
|-------------|------|-----------|
| `current_environment` | EnvironmentData? | Ambiente atualmente ativo (null se nenhum) |

| Método | Retorna | Descrição |
|--------|---------|-----------|
| `set_environment(id: String)` | void | Define o ambiente atual pelo ID |
| `get_current_environment()` | EnvironmentData? | Retorna o ambiente atual |
| `get_difficulty()` | int | Retorna a dificuldade do ambiente atual (0 se nenhum) |
| `get_all_environments()` | Array[EnvironmentData] | Retorna todos os ambientes disponíveis |

**Restrições**:
- `set_environment()` deve aceitar apenas IDs válidos; ignorar ou usar fallback para IDs inválidos
- Deve emitir warning no console para IDs inválidos

---

### BackgroundController

Controla a renderização e scroll do background.

| Propriedade | Tipo | Descrição |
|-------------|------|-----------|
| `scroll_speed` | float | Velocidade atual de scroll do background |
| `texture_height` | float | Altura da textura carregada (para cálculo de reciclagem) |
| `sprites` | Array[Sprite2D] | Pool de dois sprites para alternância |

| Método | Retorna | Descrição |
|--------|---------|-----------|
| `set_texture(path: String)` | void | Carrega e configura a textura do background |
| `update_scroll(road_speed: float, delta: float)` | void | Atualiza posição dos sprites baseado na velocidade da estrada |
| `reset()` | void | Reseta posição dos sprites para o estado inicial |

**Observações de implementação (ajuste 2026-09-23)**:
- Os assets de background foram dimensionados em **640x480** (resolução da viewport) e são renderizados em escala nativa (`scale = Vector2.ONE`) com filtro NEAREST, sem escalonamento — preservando a nitidez da pixel art.
- `texture_height` é usado como passo de reciclagem (480px), mantendo a repetição vertical contínua com o pool de 2 sprites.

**State Transitions**:
```
[Idle] → set_texture() → [Ready]
[Ready] → update_scroll() → [Scrolling]
[Scrolling] → update_scroll() → [Scrolling] (contínuo)
[Scrolling] → reset() → [Ready]
```

---

### LevelConfig (Entidade Futura — preparação apenas)

Associa um ambiente a um nível/pista. **Não implementada neste SPEC**, mas a estrutura deve suportar:

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `level_id` | int | Identificador do nível |
| `environment_id` | String | ID do ambiente associado |
| `difficulty` | int | Dificuldade do nível |

**Nota**: Esta entidade é preparação para SPECs futuros. A implementação atual não a cria, mas o `EnvironmentManager` deve ser designado para consultá-la no futuro.

---

## Data Flow

```
GameConfig (autoload)
    │
    ├── current_environment_id: "PLAINS"
    ├── background_multiplier: 0.6
    └── ENVIRONMENTS: { "PLAINS": EnvironmentData, ... }
            │
            ▼
    EnvironmentManager
            │
            ├── set_environment(id) → busca em ENVIRONMENTS
            ├── get_current_environment() → EnvironmentData
            └── get_difficulty() → int
                    │
                    ▼
            BackgroundController
                    │
                    ├── set_texture(path) → carrega textura
                    └── update_scroll(speed, delta) → move sprites
                            │
                            ▼
                    GameplayManager (orchestrator)
                            │
                            ├── Road.scroll_speed → background
                            └── PlayerVehicle.speed → Road.scroll_speed
```

## Validation Rules

| Regra | Origem | Descrição |
|-------|--------|-----------|
| ID único | FR-001, FR-002 | Cada ambiente deve ter identificador único |
| Dificuldade ≥ 1 | FR-003 | Nível de dificuldade base deve ser positivo |
| Asset fallback | Clarificação | Textura inválida → fallback para PLAINS |
| Multiplicador global | Clarificação | background_multiplier aplicado igualmente a todos |
| Scroll apenas vertical | Clarificação | Background move apenas no eixo Y |
| Ordem de renderização | FR-011 | Background → Road → PlayerVehicle |
| Pixel art preservado | FR-015 | Sem suavização, sem filtros, sem escalas fracionárias |
