# Contrato: DifficultyManager — Configuração Efetiva de Dificuldade (SPEC-009)

**Dono**: `src/difficulty/difficulty_manager.gd` (`DifficultyManager` — novo, `RefCounted`)
**Dados**: `GameConfig.difficulty_modes`, `GameConfig.difficulty_default_mode` (autoload)
**Instanciado/orquestrado por**: `GameplayManager` (não é autoload, não é Node de cena)
**Referências**: [data-model.md](../data-model.md) §2–§3, research R1/R3/R5–R8/R12

## 1. Interface pública

```gdscript
func definir_modo(id: String) -> void          # inválido → "normal" + warning
func ciclar_modo() -> String                   # relaxante → normal → desafio → relaxante; retorna o novo id
func get_modo() -> String
func aplicar_fator_ciclo(f: float) -> void     # chamado por corrida (RaceProgression.fator_ciclo())
func fator_ciclo() -> float

func multiplicador_velocidade() -> float       # difficulty_modes[modo].velocidade
func fator_velocidade_total() -> float         # multiplicador × fator_ciclo
func efetiva(base: float) -> float             # base × fator_velocidade_total()
func fator_densidade() -> float
func fator_frequencia_galoes() -> float
func fator_penalidade_colisao() -> float
func fator_distancia_galoes() -> float
```

Regras:
- Leituras são puras (sem efeitos colaterais, sem alocação).
- Fator de campo ausente na config → 1,0 (fallback seguro, FR-002).
- `aplicar_fator_ciclo` grava o valor passado — o DifficultyManager **não** conhece `RaceProgression` (evita acoplamento cíclico; quem sincroniza é o `GameplayManager`).

## 2. Pontos de injeção (uma vez no `_ready`, refresh por corrida)

| Sistema | Campo | Valor por corrida |
|---------|-------|-------------------|
| `player_vehicle.controller` | `fator_dificuldade` | `dificuldade.fator_velocidade_total()` |
| `fuel_system` | `fator_velocidade` | `dificuldade.fator_velocidade_total()` |
| `fuel_system` | `fator_penalidade_colisao` | `dificuldade.fator_penalidade_colisao()` |
| `traffic_layer` | `dificuldade` (ref) | mesma instância |
| `traffic_layer.fator_dificuldade` (seed p/ nascimentos) | `dificuldade.fator_velocidade_total()` |
| `items_layer` (FuelCanManager — a camada da cena SPEC-008 é o próprio gerenciador) | `dificuldade` (ref) | mesma instância |

**Fallback obrigatório**: qualquer campo nulo ou fator ausente nos sistemas legados = **1,0** (R12) — testes existentes que não instanciam DifficultyManager permanecem no comportamento atual.

## 3. Aplicação por sistema (pontos exatos)

- **Jogador** (`VehicleController._apply_vertical_physics`): `speed = min(speed + GameConfig.acceleration × fator × delta, GameConfig.max_speed × fator)`; frenagem e desaceleração natural × fator; `get_vertical_position()` normaliza por `max_speed × fator`. Lateral **nunca** escalado (R2).
- **NPCs** (`TrafficVehicle.get_speed()`): `category.max_speed × fator_dificuldade` — `TrafficData.max_speed` nunca é mutado (FR-003); fator gravado no `activate()` pelo `TrafficManager` (R11).
- **Densidade** (`TrafficManager._maximo_visivel_atual()`): `clamp(int(teto_ambiente × fator_densidade), traffic_min_visible, traffic_max_vehicles)` (R5).
- **Combustível** (`FuelSystem`): `_taxa_consumo` normaliza pelo teto efetivo e multiplica a taxa por `fator_velocidade` (R3); `on_player_collision` aplica `collision_fuel_penalty[ambiente] × fator_penalidade_colisao` (R7).
- **Galões** (`FuelCanManager._tentar_gerar`): `taxa = fuel_can_spawn_rate[ambiente] × fator_frequencia_galoes`; `intervalo = (fuel_can_spawn_interval_distance × fator_distancia_galoes) / max(taxa, 0,01)` (R6).

## 4. Garantias

1. Multiplicador aplicado **uma única vez** por valor (cada ponto acima é o único leitor do fator para aquele efeito).
2. `GameConfig` e `TRAFFIC_CATEGORIES` nunca são escritos pelos sistemas (só o orquestrador escreve `current_environment_id`).
3. Modo fixo durante a corrida — nada lê/seleciona modo no ramo PLAYING (FR-006).
4. Pausa/retomada não tocam nos fatores; reinício reaplica via `_on_start_race`/`_reset_corrida` (FR-006).
