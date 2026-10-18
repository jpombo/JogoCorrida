# Data Model — Sistema de Combustível (SPEC-007)

**Data**: 2026-10-09 | **Fonte**: `spec.md` §6 (modelo de dados) + decisões de `research.md`

6 entidades (exatamente as da spec). Nenhuma persistência — tudo vive durante a partida, com a configuração no autoload `GameConfig`. Convenção de validação: `capacidade > 0` é guard de todas as divisões; toda leitura de ambiente usa `GameConfig.current_environment_id`.

---

## 1. Estado de Combustível (interno a `FuelSystem`)

O tanque da partida atual. Não é uma classe separada: é o conjunto de campos privados de `src/fuel/fuel_system.gd`, imutáveis entre `reset()`s.

| Campo | Tipo | Validação | Origem |
|---|---|---|---|
| `atual` | `float` | `0.0 ≤ atual ≤ capacidade` (clamp em **toda** escrita; nunca negativo) | Inicializado no `reset()`; decrementado por consumo/penalidade |
| `capacidade` | `float` | `> 0.0` (guard: capacidade `0` ⇒ sem eventos, sem divisão) | `GameConfig.fuel_capacity` |
| `_baixo_sinalizado` | `bool` | — | Latch rearmed no `reset()` (R5) |
| `_esgotado_emitido` | `bool` | — | Latch rearmed no `reset()` (R5) |

**Transições** (diagrama textual):

```
reset()                ──► CHEIO: atual = (initial < 0 ? capacidade : clamp(initial, 0, capacidade))
                             ├─ avalia limiar; se abaixo, emite fuel_low 1× e arma latch (caso de borda 15)
                             └─ rearma _esgotado_emitido = false
update(delta, v)       ──► se atual == 0: no-op de consumo (FR-010) — apenas reavalia fuel_low
                             senão: atual = clamp(atual − taxa(delta, v), 0, capacidade)
                         ──► se cruzou/atingiu 0: emite fuel_depleted 1× e arma latch
on_player_collision()  ──► atual = clamp(atual − penalidade(ambiente), 0, capacidade)
                             (penalidade 0 ⇒ nada muda; esgotar por colisão também emite fuel_depleted)
```

**Invariantes** (testadas por todas as suítes): monotonicidade não-crescente fora de `reset()`; pós-`fuel_depleted` nenhuma escrita altera `atual` (fica 0); nenhum evento duplicado por latch.

---

## 2. Configuração de Combustível (bloco em `GameConfig`)

| Campo | Tipo | Validação | Origem / padrão (semente, R9) |
|---|---|---|---|
| `fuel_capacity` | `float` `@export` | `> 0.0` | `100.0` |
| `fuel_initial_amount` | `float` `@export` | `-1.0` = usar capacidade; senão `clamp(v, 0, capacidade)` | `-1.0` |
| `fuel_consumption_idle` | `float` `@export` | `≥ 0.0` | `0.0` |
| `fuel_consumption_min` | `float` `@export` | `≥ 0.0` | `0.6` |
| `fuel_consumption_max` | `float` `@export` | `≥ fuel_consumption_min` | `2.0` |
| `fuel_consumption_speed_factor` | `float` `@export` | `≥ 0.0` (derivado: `max − min`) | `1.4` |
| `fuel_low_threshold` | `float` `@export` | `0.0 < v ≤ 1.0` (fração da capacidade) | `0.2` |
| `collision_fuel_penalty` | `Dictionary[String, float]` `@export` | valores `≥ 0.0`; **chave ausente ⇒ `0.0`** | `{PLAINS:0, DESERT:0, FOREST:3, ICE:3}` (R3) |
| `fuel_low_label` | `String` `@export` | não-vazio | `"BAIXO"` (§VI) |

Fórmulas derivadas (não são campos): `normalizada = clamp(v / max_speed, 0, 1)`; `taxa = min + normalizada × factor`, com teto `max`; limiar absoluto = `fuel_low_threshold × capacidade`.

---

## 3. Evento de Alteração (`fuel_changed`)

| Campo | Tipo | Quando emite | Consumidor |
|---|---|---|---|
| `atual` | `float` | A cada variação **real** de `atual` (consumo ou penalidade), com `is_equal_approx` contra o valor anterior | HUD (largura da barra) |
| `capacidade` | `float` | Idem — muda só se a config mudar em runtime | HUD (proporção) |

**Não emite**: quadro sem variação; após esgotado (valor já 0, sem mudança); antes do primeiro `reset()`.

---

## 4. Evento de Combustível Baixo (`fuel_low`)

| Campo | Tipo | Quando emite | Consumidor |
|---|---|---|---|
| *(sem payload)* | `void` | **1×** quando `atual ≤ limite_absoluto`, seja por consumo, por colisão ou já no `reset()` inicial; rearma só no próximo `reset()` | HUD (cor do preenchimento + rótulo) |

O **estado persistente** (cor/rótulo enquanto abaixo do limiar, Clarification B) é derivado: o HUD recalcula a visibilidade a partir de `fuel_changed` + um getter `esta_baixo()` — o sinal marca a *travessia*, o estado marca a *permanência*.

---

## 5. Evento de Esgotamento (`fuel_depleted`)

| Campo | Tipo | Quando emite | Consumidor |
|---|---|---|---|
| *(sem payload)* | `void` | **1×** por partida, na primeira vez que `atual` atinge `0.0` (origem: consumo lento ou desconto de colisão); rearma só no `reset()` | SPEC-008 (Game Over/vitória); durante 007: observável em teste |

---

## 6. Penalidade de Colisão (contexto da avaliação)

| Campo | Tipo | Validação | Origem |
|---|---|---|---|
| `ambiente` | `String` | Chave de `collision_fuel_penalty`; ausente ⇒ `0.0` | `GameConfig.current_environment_id` **no momento do evento** (FR-016) |
| `valor` | `float` | `≥ 0.0`; aplicado com `clamp` ao zero do tanque | `collision_fuel_penalty.get(ambiente, 0.0)` |
| *(ignorados)* | `CollisionData` | Payload lido apenas como sinal de "houve colisão" | `collision_occurred` (SPEC-005) — ver R2/R10 |

Sem estado: cada evento é avaliado isoladamente, **sem memória** de colisões anteriores (SC-012: trocar ambiente não retroage descontos já feitos).

---

## Relação com o HUD (não é entidade)

`FuelHud` **observa** a Estado (§3/§4): `fuel_changed` ⇒ largura; estado baixo ⇒ cor + rótulo. Nunca escreve de volta (§Sistema de Combustível — UI como observadora; teste T26 afirma).
