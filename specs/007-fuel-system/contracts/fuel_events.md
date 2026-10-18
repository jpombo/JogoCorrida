# Contrato: Eventos do FuelSystem (SPEC-007)

**Emissor**: `src/fuel/fuel_system.gd` (`FuelSystem`)
**Consumidores**: `src/ui/fuel_hud.gd` (observador), SPEC-008 (Game Over/vitória — consumo futuro), suítes `tests/unit/fuel_*_test.gd`

Todos os sinais são emitidos **apenas** dentro de chamadas a `update()`/`reset()`/`on_player_collision()` — nunca em `_process` próprio (o FuelSystem não tem loop).

---

## 1. `fuel_changed(atual: float, capacidade: float)`

| Item | Regra |
|---|---|
| Payload | `atual` (valor pós-operação, já com clamp `[0, capacidade]`), `capacidade` (constante durante a partida) |
| Emite quando | `reset()` define o valor inicial; `update()` consome; `on_player_collision()` desconta — **e apenas se** `atual` difere do anterior (`is_equal_approx` negativo) |
| Não emite | Quadro sem variação; após esgotado (valor 0 estagnado); antes do primeiro `reset()` |
| Garantia | `0 ≤ atual ≤ capacidade` em **todo** payload |

## 2. `fuel_low()`

| Item | Regra |
|---|---|
| Payload | nenhum |
| Emite quando | A **travessia** do limiar `atual ≤ fuel_low_threshold × capacidade`, por qualquer via (consumo, colisão ou valor inicial já abaixo — caso de borda 15) |
| Frequência | **No máximo 1× por partida** — latch `_baixo_sinalizado`, rearmado **somente** em `reset()` |
| Não emite | Quadros repetidos abaixo do limiar; se `capacidade ≤ 0` (guard de divisão) |

## 3. `fuel_depleted()`

| item | Regra |
|---|---|
| Payload | nenhum |
| Emite quando | Primeira vez que `atual` atinge `0.0` — origem indiferente (consumo em `update()` **ou** desconto em `on_player_collision()`) |
| Frequência | **No máximo 1× por partida** — latch `_esgotado_emitido`, rearmado **somente** em `reset()` |
| Não emite | Repeated checks com `atual` já 0; após o rearma do `reset()` haverá no máximo 1 novo disparo |

---

## API pública (para wiring/testes)

```gdscript
func reset() -> void
    # Rearma latches; define `atual` (sentinela −1 ⇒ capacidade); emite fuel_changed e,
    # se inicial ≤ limiar, fuel_low. Chamado EXCLUSIVAMENTE em READY→PLAYING (R4).

func update(delta: float, velocidade: float) -> void
    # Consome `taxa(delta, velocidade) * delta` com clamp; reavalia baixo/esgotado.
    # Sem efeito se `atual == 0`. Chamado apenas no ramo PLAYING (R4).

func on_player_collision(_data: CollisionData = null) -> void
    # Desconta `collision_fuel_penalty[GameConfig.current_environment_id]` com clamp a 0.
    # Conectado a `CollisionSystem.collision_occurred` (1 evento = 1 desconto, R2).

func esta_baixo() -> bool
    # Estado persistente p/ o HUD: `atual ≤ limiar` (derivado, não-latch).

func get_atual() -> float
func get_capacidade() -> float
```

**Proibições** (testadas, constituem o contrato): nenhum método escreve em `VehicleController`/estados/pista; nenhum sinal é emitido fora das 3 chamadas acima; nenhum evento se repete por partida além do limite dos latches (SC-013).
