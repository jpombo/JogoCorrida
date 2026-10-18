# Data Model — Progressão, Estados, Combustível e Galões (SPEC-008)

**Data**: 2026-10-10 | **Fonte**: `spec.md` §Key Entities + decisões de `research.md`

As 6 entidades da spec, mapeadas às estruturas de código. Nenhuma persistência — tudo vive durante a partida; a configuração fica no autoload `GameConfig`. Convenções: `total > 0` é guard de todas as razões de progresso; toda leitura de ambiente usa `GameConfig.current_environment_id`; distâncias da corrida em **km**, espaçamentos de itens em **px**, combustível em **unidades abstratas** (SPEC-007).

---

## 1. Estado de Jogo (`src/game/game_state.gd` — existente, exercitado)

Já implementado com os 6 estados; a SPEC-008 passa a **usar** `victory()` e `game_over()` (hoje nunca chamados) e a centralizar as rotas de reinício/menu.

| Campo | Tipo | Regra |
|---|---|---|
| `current_state` | `State` | exatamente 1 ativo; só `GameState` o altera (FR-001) |
| `previous_state` | `State` | para retomada/UI |
| `state_changed` | sinal | consumido por `GameplayManager` e `UIManager` |

**Transições (todas via métodos de `GameState`)**:

```
MENU ──start_game()──► READY ──begin_playing()──► PLAYING ──pause_game()──► PAUSED
                                                      │                        │
                                                      │            resume_game()──► PLAYING
                    victory() ◄──(cruzamento + combustível)────────────────────┘
                    game_over() ◄──(parado com zero e sem concluir)────────────┘
MENU/reset() ◄──(reinício / voltar ao menu a partir de qualquer estado)
```

Invariantes: `change_state` no-op no mesmo estado (eventos de fim nunca duplicam — SC-005/SC-007); `victory()`/`game_over()` só são chamados pelo `GameplayManager` no passo de transição (research R9).

---

## 2. Corrida / Progressão (`src/track/track_manager.gd` — NOVO)

| Campo | Tipo | Validação | Origem |
|---|---|---|---|
| `total` | `float` (km) | `> 0` (guard de config; erro de config limita aos válidos) | `GameConfig.track_total_distance` lido no reset |
| `percorrida` | `float` (km) | `0 ≤ percorrida ≤ total`; monotônica não-crescente | integração por quadro (research R1) |
| `restante` | `float` (km) | `= total − percorrida` | derivado |
| `percentual` | `float` | `[0, 1]`; `total ≤ 0` ⇒ `1.0` | derivado |
| `concluido` | `bool` | só vira `true` na transição de vitória | transição (R9) |
| `posicao_logica_chegada` | `float` (px no mundo) | `= player_y_inicial − total / track_units_to_km` | criada no reset, movida pela rolagem |

**Transições** (chamadas só no ramo `PLAYING`):

```
reset()            ──► percorrida = 0; concluido = false; emite progress_changed(0, total, 0)
update(delta, v)   ──► percorrida = min(percorrida + v × track_units_to_km × delta, total)
                       emite progress_changed apenas em variação real
marcar_concluido() ──► concluido = true  (chamado pelo GameplayManager na vitória)
```

Invariantes: nunca decresce; nunca ultrapassa `total` (SC-003/SC-004); parado/pausado não acumula; lateral não acumula (Clarificação de faixa).

---

## 3. Marcador de Pista (`src/track/track_markers.gd` — NOVO)

Dois elementos do mundo da pista, filhos de um `Node2D` no layer da estrada. Construídos com `ColorRect` (banda quadriculada 2×N células alternadas) + `Label` (rótulo de `GameConfig`); escala inteira, `TEXTURE_FILTER_NEAREST`.

| Campo | Tipo | Regra |
|---|---|---|
| `tipo` | enum `INICIO`/`CHEGADA` | define rótulo e comportamento |
| `position.y` inicial | `float` | início: `player_y` na largada; chegada: `player_y − total / track_units_to_km` (R2) |
| deslocamento | — | `y += road.scroll_speed × delta` em PLAYING (mesma rolagem da estrada) |
| `ativo` | `bool` | início: `false` definitivamente ao sair completamente da tela (FR-010); chegada: permanece até a conclusão |

**Vitória geométrica** (avaliada pelo `GameplayManager`, R9):

```
cruzou = banda.top_y >= player.position.y + player_hitbox.y / 2
vitória = PLAYING and fuel_atual > 0 and cruzou and not corrida_encerrada
```

Invariantes: 0 reaparecimentos do início na mesma corrida (SC-002); posição idêntica após pausa (SC-012).

---

## 4. Galão de Gasolina (`src/items/fuel_can.gd` + `fuel_can_manager.gd` — NOVOS)

**Item** (`fuel_can.gd` — `Node2D` com `Sprite2D` + retângulo de contato):

| Campo | Tipo | Validação |
|---|---|---|
| `textura` | `Texture2D` | `gasolina.png` 32×51 (FR-021; sem redesenho) |
| `position` | `Vector2` | dentro dos limites dirigíveis vigentes no nascimento (FR-022) |
| `area_contato` | `Rect2` (32×51 centrada) | área própria de coleta — **não** entra em nenhum sistema de colisão (R8) |
| `estado` | enum `ATIVO`/`COLETADO` | coleta exatamente 1×; `COLETADO` ⇒ devolução imediata ao pool |

**Gerenciador** (`fuel_can_manager.gd`):

| Campo | Tipo | Regra |
|---|---|---|
| `pool` | `Array[FuelCan]` | reutilização com posição/estado/referências redefinidos (FR-031, SC-011) |
| `ativos` | `Array[FuelCan]` | ≤ `fuel_can_max_active` em todo quadro |
| `gerados_na_corrida` | `int` | total gerado; `fuel_can_min_per_race ≤ gerados ≤ fuel_can_max_per_race` por corrida (Clarificação) |
| `distancia_desde_ultima` | `float` (km) | integra `speed × track_units_to_km × delta`; zera no spawn |
| `spawn_pendente` | `Dictionary` | candidato invalidado reavaliado a cada quadro até nascer ou expirar no próximo intervalo (FR-030) |

**Sinais**: `fuel_can_spawned(can)`, `fuel_can_collected(restaurado: float)` (FR-032).

**Transições de ciclo de vida**:

```
update(...) em PLAYING (scroll > 0):
    mover ativos (y += scroll × delta); coletar sobreposições; reciclar quem saiu da base
    → pool (reapresentação posterior, Clarificação)
    gerar se regras de R7 passarem (distância, taxa ambiente, piso/teto, offsets, espaçamentos, NPCs)
reset(): todos ao pool; contadores zerados; pendências limpas
encerramento (VICTORY/GAME_OVER/menu/restart): idem reset — 0 ativos após o fim (SC-011)
```

Invariantes: sem velocidade própria (só rolagem — Clarificação); coleta sem consequência de colisão (SC-009); nunca sobre NPC, com espaço para interagir sem colidir (FR-022/FR-030, SC-010); reciclagem nunca ressuscita coletado (FR-030).

---

## 5. Estado de Combustível (interno a `FuelSystem` — SPEC-007, estendido)

Campos existentes (`_atual`, `_capacidade`, latches) + campo novo:

| Campo | Tipo | Regra |
|---|---|---|
| `_capacidade_derivada` | `float` | `-1.0` = sem override; `≥ 0` = capacidade da corrida (R3) |

**Transições novas** (aditivas; o restante do contrato SPEC-007 permanece):

```
definir_capacidade_derivada(cap)  ──► _capacidade_derivada = max(cap, 0.0)  (ou -1.0 p/ limpar)
reset()                           ──► _capacidade = max(derivada se ≥ 0, senão GameConfig.fuel_capacity, 0)
restaurar(valor)                  ──► _escrever(clamp(_atual + max(valor, 0), 0, _capacidade))
                                       tanque cheio ⇒ no-op silencioso; sem rearme; sem fuel_depleted
```

Invariantes preservadas: `0 ≤ atual ≤ capacidade` em toda escrita; `fuel_depleted` único por corrida (sem rearme — Clarificação); nenhum evento duplicado; autoridade exclusiva do sistema (FR-033).

---

## 6. Configuração de Progressão e Itens (bloco em `GameConfig` — NOVO)

Sementes **CALIBRAÇÃO** (research R13); legíveis por todos os sistemas, origem única do balanceamento (FR-039, SC-016).

| Campo | Tipo | Semente | Usado por |
|---|---|---|---|
| `track_total_distance` | `float` (km) | `5.0` | TrackManager, fórmula de dimensionamento |
| `track_units_to_km` | `float` | `0.00034722` | TrackManager, FuelCanManager, posicionamento da chegada |
| `fuel_consumption_per_distance` | `float` (un/km) | `40.0` | fórmula de dimensionamento |
| `fuel_safety_margin` | `float` (un) | `60.0` | fórmula de dimensionamento |
| `fuel_can_restore_amount` | `float` | `25.0` | restauração (global, Clarificação) |
| `fuel_can_spawn_interval_distance` | `float` (km) | `0.35` | geração |
| `fuel_can_min_spacing` | `float` (px) | `120.0` | geração (galão×galão) |
| `fuel_can_npc_spacing` | `float` (px) | `24.0` | geração (galão×NPC) |
| `fuel_can_start_offset` | `float` (km) | `0.15` | geração |
| `fuel_can_finish_offset` | `float` (km) | `0.25` | geração |
| `fuel_can_max_active` | `int` | `3` | geração (teto simultâneo) |
| `fuel_can_min_per_race` / `fuel_can_max_per_race` | `int` | `4` / `12` | geração (total por corrida) |
| `fuel_can_spawn_rate` | `Dictionary` | PLAINS 1.4 / DESERT 1.0 / FOREST 0.7 / ICE 0.5 | geração (taxa × ambiente) |
| `ui_*` | `String`/`Dictionary` | rótulos pt-BR | UIManager, marcadores, formato de distância |

Rótulos externados (§VI, FR-041): título do menu, "Selecionar veículo", nomes dos veículos, `INÍCIO`, `CHEGADA`, template do indicador (`"Distância: %.1f km / %.1f km"`), "Vitória"/"Fim de jogo", "Continuar", "Reiniciar", "Tentar novamente", "Voltar ao menu", "Pausa".

---

## 7. Eventos da Corrida (sinais consolidados)

| Evento | Emissor | Consumidor(s) | Unicidade |
|---|---|---|---|
| `state_changed` | `GameState` | GameplayManager, UIManager | por mudança real de estado |
| `fuel_changed` / `fuel_low` / `fuel_depleted` | `FuelSystem` | FuelHud, GameplayManager (GAME_OVER) | contrato SPEC-007 inalterado |
| `progress_changed(percorrida, total, percentual)` | `TrackManager` | UIManager (indicador), GameplayManager | por variação real |
| `fuel_can_spawned(can)` | `FuelCanManager` | UI/debug, testes | 1× por nascimento |
| `fuel_can_collected(restaurado)` | `FuelCanManager` | GameplayManager → `fuel_system.restaurar` | 1× por coleta (SC-009/SC-015) |
| `race_won` / `race_lost` | `GameplayManager` (pós-transição) | UI, testes | 1× por corrida (SC-005) |
