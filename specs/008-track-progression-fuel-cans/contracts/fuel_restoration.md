# Contrato: Extensões do FuelSystem (SPEC-008)

**Emissor**: `src/fuel/fuel_system.gd` (`FuelSystem` — SPEC-007, estendido aditivamente)
**Consumidores**: `GameplayManager` (dimensionamento/reset/restauração), `FuelCanManager` (indireto), suítes `fuel_*` e `fuel_sizing_test.gd`

Os sinais `fuel_changed`/`fuel_low`/`fuel_depleted` e todos os métodos da SPEC-007 permanecem **inalterados** (`specs/007-fuel-system/contracts/fuel_events.md` continua válido).

## 1. `definir_capacidade_derivada(capacidade: float)`

| Item | Regra |
|---|---|
| Efeito | grava `_capacidade_derivada = maxf(capacidade, 0.0)`; `-1.0` (ou qualquer valor negativo) **limpa** o override |
| Quando aplicado | ANTES do `reset()` da corrida, a cada nova corrida (READY → PLAYING) |
| Efeito no `reset()` | `_capacidade = maxf(override se ≥ 0, senão GameConfig.fuel_capacity, 0.0)` |
| Sem chamada | comportamento idêntico à SPEC-007 (suítes existentes não mudam) |
| Limite | capacidade derivada respeita os limites válidos do sistema (`≥ 0`); fórmula `distância × consumo_por_km + margem` é responsabilidade do chamador |

## 2. `restaurar(valor: float)`

| Item | Regra |
|---|---|
| Efeito | `_escrever(clampf(_atual + maxf(valor, 0.0), 0.0, _capacidade))` |
| Emite | `fuel_changed` **apenas** em variação real (tanque já cheio ⇒ no-op silencioso, mas o galão ainda é coletado) |
| Nunca emite | `fuel_depleted` (restauração não esgota); nenhum evento novo de baixo |
| Latches | **sem rearme** (Clarificação 2026-10-10): `_esgotado_emitido`/`_baixo_sinalizado` inalterados; o desbloqueio de aceleração deriva do valor atual, não do latch |
| Com tanque em zero | escreve normalmente (valor volta a ser positivo) |
| Autoridade | único caminho externo de escrita de combustível (FR-033/FR-038); `valor` vem sempre de `GameConfig.fuel_can_restore_amount` |

## 3. Invariante de regressão

`reset()` sem `definir_capacidade_derivada` prévia deve reproduzir **exatamente** o comportamento validado das 6 suítes da SPEC-007 (SC-013).
