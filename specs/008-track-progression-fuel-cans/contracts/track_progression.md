# Contrato: Progressão da Pista — TrackManager (SPEC-008)

**Emissor**: `src/track/track_manager.gd` (`TrackManager`)
**Consumidores**: `GameplayManager` (update/vitória), `UIManager` (indicador), `FuelCanManager` (offsets), suítes `tests/unit/track_*_test.gd`

---

## 1. `progress_changed(percorrida: float, total: float, percentual: float)`

| Item | Regra |
|---|---|
| Payload | `percorrida` (km, pós-update, já com clamp), `total` (km, constante da corrida), `percentual` `[0, 1]` |
| Emite quando | `reset()` define o zero inicial; `update()` varia `percorrida` de fato (`is_equal_approx` negativo) |
| Não emite | Quadro sem avanço (parado, pausado, troca de faixa, fora de `PLAYING`) |
| Garantia | `0 ≤ percorrida ≤ total` em **todo** payload (SC-003/SC-004) |

---

## 2. API pública

| Método | Regra |
|---|---|
| `setup(total_km: float)` | chamado 1× pelo `GameplayManager._ready`; define `total` (não re-emite) |
| `reset()` | `percorrida = 0`, `concluido = false`, `posicao_logica_chegada` recalculada; emite `progress_changed(0, total, 0)` |
| `update(delta: float, velocidade_avanco: float)` | **só chamado no ramo `PLAYING`**; integra `velocidade × track_units_to_km × delta`; `velocidade ≤ 0` ⇒ no-op; nunca decrementa |
| `marcar_concluido()` | chamado **apenas** pelo `GameplayManager` na vitória; liga `concluido` |
| `get_percorrida() / get_restante() / get_percentual() / esta_concluido()` | leituras puras |

## 3. Regras de consistência

- **Fonte única de avanço**: o chamador passa a **mesma** velocidade que alimenta a rolagem (`PlayerVehicle.get_speed()`); lateral nunca entra (Clarificação 2026-10-10).
- **Unidades**: `km`; a conversão usa somente `GameConfig.track_units_to_km` (nenhuma constante solta).
- **Pausa/menu/fim**: o chamador para de chamar `update` — o estado fica congelado sem acúmulo (FR-004).
- O TrackManager **não** decide vitória/estado — só reporta progresso; a transição é do `GameplayManager` via `GameState` (FR-001).
