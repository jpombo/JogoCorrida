# Data Model — Recordes, Persistência, Troféus, Pontuação e Obstáculos (SPEC-011)

Fase 1 do `/speckit.plan`. Entidades de domínio (memória), esquema persistido (JSON) e estados dos obstáculos/efeitos. As chaves de modo são **exatamente** as de `GameConfig.difficulty_modes` (research R10): `"relaxing"`, `"normal"`, `"challenge"`.

## 1. Entidades de domínio (memória)

### 1.1 Resultado de corrida (registro do histórico)

Registrado **uma única vez por vitória** (FR-001/FR-003); distinto dos totais acumulados.

| Campo | Tipo | Origem | Regra |
|---|---|---|---|
| `modo` | String | `DifficultyManager.get_modo()` | chave canônica |
| `ambiente` | String | `RaceProgression.ambiente_atual()` capturado **antes** de `registra_vitoria()` | `"PLAINS"/"DESERT"/"FOREST"/"ICE"` |
| `distancia` | float | `TrackManager` (medida única) | nunca > `track_total_distance` |
| `pontuacao` | float | `calcular_pontuacao()` | ≥ 0 (clamp configurado) |
| `trofeus` | int | total do modo **após** marcar o ambiente da corrida | inclui o troféu da própria corrida (FR-006) |
| `perda_colisao` | float | `FuelSystem.get_perda_colisao_corrida()` | 0,0 em corridas sem colisão/perda |
| `data_hora` | String | `Time.get_datetime_string_from_system()` | `""` se indisponível (não invalida) |

### 1.2 Estado por modo (`ModoProgresso`)

Um dicionário por chave canônica dentro de `ProgressManager`:

| Campo | Tipo | Regra |
|---|---|---|
| `recorde` | float | maior `pontuacao` já registrada; atualiza só se `>` estrito (FR-002) |
| `acumulada` | float | soma das pontuações dos resultados do modo (exibida — decisão Q5/A) |
| `trofeus` | int | total permanente; nunca decresce |
| `ciclo` | Array[String] | ambientes marcados **no ciclo atual** (0–4 entradas, sem repetição) |

### 1.3 `ProgressManager` (campo raiz)

| Campo | Tipo | Regra |
|---|---|---|
| `_modos` | Dictionary[String → ModoProgresso] | sempre com as 3 chaves materializadas (defaults na carga) |
| `_historico` | Array[Dictionary] | últimos resultados, trim por `score_historico_max` |

### 1.4 Desbloqueio dos obstáculos (derivado — FR-019)

**Sem campo armazenado.** `obstaculos_disponiveis(modo) -> bool`:

- `modo != "relaxing"` → `true` sempre (FR-018);
- `modo == "relaxing"` → `trofeus["relaxing"] >= 1`.

Derivado do total já persistido ⇒ desbloqueio sobrevive a reinício sem segundo dado e **nunca** é afetado por troféus de outros modos (SC-007).

### 1.5 Snapshot de UI (contrato de exibição)

Dicionário devolvido por `progresso.snapshot(modo, pontuacao_opcional)` e consumido pela `UIManager` (`contracts/ui_progress_display.md`):

```text
{
  "modo": String,              # chave canônica
  "recorde": float,
  "acumulada": float,
  "trofeus": int,
  "progresso_k": int,          # |ciclo| atual, 0..4
  "desbloqueado": bool,        # obstáculos liberados neste modo
  "pontuacao": float,          # sempre presente; -1 = sem pontuação de corrida (derrota/menu); > 0 só em vitória (fonte: contracts/ui_progress_display.md §4)
}
```

## 2. Fórmula de pontuação (FR-004…FR-008)

```text
pontuacao = clamp(
      distancia_km  × GameConfig.score_peso_distancia
    + trofeus_modo  × GameConfig.score_peso_trofeu
    − perda_colisao × GameConfig.score_peso_penalidade
  , 0.0, INF)
```

- `trofeus_modo` = total **após** o `marcar_ambiente()` da corrida em análise (inclui o troféu recém-conquistado — Assumption da spec);
- `perda_colisao` = acúmulo real descontado do `FuelSystem` (research R4) — consumo normal nunca entra;
- clamp em 0 evita pontuação negativa (penalidade alta em corrida curta) sem afetar a comparação de recorde.

Ordem canônica do encerramento (`processar_vitoria`) — FR-008/SC-003:

```text
1. marcar_ambiente(modo, ambiente)     # pode conceder troféu e zerar o ciclo
2. pontuacao = calcular_pontuacao(...) # usa o total já atualizado
3. recorde = max(recorde, pontuacao)   # só se pontuacao > recorde
4. acumulada += pontuacao
5. historico.append(resultado); trim(score_historico_max)
6. snapshot → orquestrador → save.gravar(dados_para_salvar())  # 1 escrita
```

Derrota (`processar_derrota`): zerar `ciclo` do modo (`trofeus` e demais campos preservados) → snapshot (sem `pontuacao`) → save. Nenhum resultado é criado (Q2-B).

## 3. Esquema persistido — `user://progresso.json`

Formato v1 (`"versao": 1`); escrita atômica (tmp + rename, research R1). Defaults aplicados por `carregar_de()` — campos faltantes em modos são completados, campos desconhecidos são ignorados (tolerância forward-compatible).

```json
{
  "versao": 1,
  "modos": {
    "relaxing":  { "recorde": 0.0, "acumulada": 0.0, "trofeus": 0, "ciclo": [] },
    "normal":    { "recorde": 0.0, "acumulada": 0.0, "trofeus": 0, "ciclo": [] },
    "challenge": { "recorde": 0.0, "acumulada": 0.0, "trofeus": 0, "ciclo": [] }
  },
  "historico": [
    {
      "modo": "normal",
      "ambiente": "DESERT",
      "distancia": 5.0,
      "pontuacao": 825.0,
      "trofeus": 1,
      "perda_colisao": 15.0,
      "data_hora": "2026-10-17T21:30:00"
    }
  ]
}
```

Regras de carga (FR-022/SC-010, edge cases):

| Situação | Comportamento |
|---|---|
| Arquivo ausente | `{}` → defaults na memória; **não grava** até o primeiro encerramento |
| JSON inválido / `parse_string` nulo | mesmos defaults; arquivo permanece intacto no disco |
| `"versao"` desconhecida maior | carrega o que entender dos campos conhecidos; nunca destrói o resto |
| Modo faltante no `modos` | materializa com defaults |
| `ciclo` com entrada repetida ou ambiente inválido | dedup + descarte de inválidos na carga |
| `historico` acima do teto | trim das entradas mais antigas na carga |
| Gravação falha no meio | `.tmp` é descartado; o arquivo anterior fica válido (nunca sobrescrever dados válidos) |

## 4. Obstáculos e efeitos

### 4.1 Obstáculo (item do pool)

| Campo | Tipo | Regra |
|---|---|---|
| `tipo` | String | `"poca"` ou `"cascalho"` (sorteado por pesos no spawn) |
| `position` / textura | da Sprite2D | dentro dos limites da pista + margem de largura |
| `hitbox` | Ret2 | `obstaculo_tamanho_*` do config — **idêntico** ao sprite (SC-008) |
| estado | enum | `INATIVO` (pool) → `ATIVO` (rolando) → **poça**: `ATINGIDO` (inerte após o desvio, reciclada ao sair da tela); **cascalho**: reciclado no impacto; ambos reciclados ao cruzar a base |

### 4.2 `ObstacleManager` (por corrida)

| Campo | Tipo | Regra |
|---|---|---|
| `distancia_desde_spawn` | float | rolagem acumulada; `reset()` zera (padrão galões) |
| `pool` | Array[Obstacle] | pré-criada, tamanho `obstaculo_max_ativos` |
| `disponivel` | bool | gate por corrida (FR-018/FR-019), definido no `_reset_corrida` |

Spawn: ao cruzar `obstaculo_intervalo_km`, sortear tipo e tentar posicionar; falha numa validação ⇒ reagendar +0,1 km (research R6). Detecção AABB por quadro com o hitbox do jogador (research R3) → **cascalho**: `aplicar_efeito_cascalho(...)` + reciclagem imediata; **poça** (ajuste T032): desvio lateral de `player.position.x ± poca_desvio_lateral` pelo lado do impacto (clamp nas bordas da pista) + estado `ATINGIDO` (permanece inerte na pista até sair da tela).

### 4.3 Efeito temporizado no `VehicleController` (cascalho)

> A poça **não** tem campos no veículo desde o ajuste T032 — o desvio é aplicado pelo `ObstacleManager` (§4.2).

| Efeito | Campos | Efeito sobre o veículo | Fim |
|---|---|---|---|
| Cascalho | `efeito_velocidade_tempo/fator` + `efeito_aderencia_cascalho` | teto = `max_speed × fator_dificuldade_total × fator` limitado a cada quadro; estabilidade via `efeito_aderencia_cascalho` (padrão 1,0 = desligada) | tempo ≤ 0 ⇒ fator 1,0 |

Invariantes (FR-016): renovação por **sobrescrita** (nunca soma); `reset()` limpa o efeito; tick só em `_process` — pausado em MENU/PAUSED/VICTORY/GAME_OVER por `set_process(false)` do `PlayerVehicle` (congelamento por construção). O desvio da poça não é temporal: acontece uma vez, sem tick e sem o que congelar (a detecção simplesmente não roda fora de PLAYING).

## 5. Configuração nova (`game_config.gd`)

- `score_peso_distancia`, `score_peso_trofeu`, `score_peso_penalidade`, `score_historico_max`;
- `poca_desvio_lateral` (ajuste T032 — substitui os 3 parâmetros antigos de aderência);
- `cascalho_velocidade_fator`, `cascalho_duracao`, `cascalho_aderencia_fator`;
- `obstaculo_intervalo_km`, `obstaculo_max_ativos`, `obstaculo_min_spacing`, `obstaculo_npc_spacing`, `obstaculo_start_offset_km`, `obstaculo_finish_offset_km`, `obstaculo_peso_poca`, `obstaculo_peso_cascalho`;
- `trofeu_assets` (Dictionary modo→path), `obstaculo_poca_path`, `obstaculo_cascalho_path`, `obstaculo_tamanho_poca`, `obstaculo_tamanho_cascalho`;
- `save_arquivo` (padrão `"user://progresso.json"`);
- `ui_strings` novas: `record_label`, `accumulated_label`, `trophy_format`, `obstacles_available`, `obstacles_locked`, `victory_score` (`score_label` removida no T042 — a pontuação só aparece via `victory_score`).

Sementes de valores: research R13.
