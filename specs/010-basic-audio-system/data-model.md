# Data Model — Sistema Básico de Áudio (SPEC-010)

Fase 1 do `/speckit.plan`. Referências: [spec.md](./spec.md) (Key Entities, FRs, SCs), [research.md](./research.md) (R1–R11).

## 1. Visão geral

O sistema **não tem persistência** e não cria entidades de gameplay: são dois artefatos de dados lógicos (o **efeito sonoro** e a **voz/veículo sonorizado**), um **dicionário de associação** veículo→voz e uma **matriz de reprodução por estado**. Nenhuma entidade existente ganha campo — `TrafficData`, `TrafficVehicle`, `CollisionData`, `NpcCollisionData` e `GameState` são apenas observados (FR-008, SC-009).

```text
GameConfig (autoload)          GameplayManager (orquestador)
  audio_* (paths, volumes,       forwards: colisão, trânsito,
           vozes, categoria)               estado ───────────┐
        │ configurar(cfg)                                      │
        ▼                                                      ▼
              AudioManager (Node, novo)
              ├── streams carregados: colisao | caminhao | carro
              ├── pool de vozes de motor (traffic_max_vehicles + 1)
              ├── pool de vozes de colisão (audio_vozes_colisao)
              └── dicionário: TrafficVehicle → voz de motor
```

## 2. Efeito Sonoro (AUD-001 a AUD-003) — dados em `GameConfig`, stream em runtime

| ID | Efeito | Chave de path (`@export`) | `loop` | Volume (config) | Stream em runtime |
|----|--------|---------------------------|--------|-----------------|-------------------|
| AUD-001 | Colisão | `audio_colisao_path` = `res://assets/audio/colisao.mp3` | `false` (one-shot, 2,12 s) | `audio_volume_colisao` (1,0) | `AudioStreamMP3` ou **mudo** (`null`) |
| AUD-002 | Motor de caminhão | `audio_caminhao_path` = `res://assets/audio/caminhao.mp3` | **`true`** (aplicado em runtime — R1) | `audio_volume_motor` (0,8) | `AudioStreamMP3` ou **mudo** (`null`) |
| AUD-003 | Motor de carro | `audio_carro_path` = `res://assets/audio/carro.mp3` | **`true`** (aplicado em runtime — R1) | `audio_volume_motor` (0,8) | `AudioStreamMP3` ou **mudo** (`null`) |

**Regras de validação**:
- `ResourceLoader.exists(path)` falso ou `load()` nulo ⇒ efeito marcado mudo (`efeito_mudo() == true`); **nenhum** método daquele efeito emite erro ou interrompe o jogo (FR-004/SC-008).
- A `Resource` é carregada **uma vez** em `configurar()` e compartilhada por todos os players da pool (R1).
- `loop` é aplicado aos streams de motor logo após o `load`, sempre (não depende do `.import` da máquina).
- Trocar um arquivo = trocar o path no `GameConfig` (§Independência de Assets; FR-007).

## 3. Voz de Motor (entidade de runtime — `AudioStreamPlayer` da pool)

| Campo | Tipo | Regra |
|-------|------|-------|
| player | `AudioStreamPlayer` | Criado **uma vez** em `configurar()`; total = `vozes_motor` = `traffic_max_vehicles + 1` (R5) |
| stream | `AudioStreamMP3 \| null` | AUD-002 se `veiculo.category.id == GameConfig.audio_categoria_caminhao`, senão AUD-003 (R6); jogador ⇒ sempre AUD-003 |
| dono | `TrafficVehicle \| "jogador" \| null` | Índice 0 é **dedicado ao jogador** (nunca vai para a lista livre); demais saem da lista livre em `ao_veiculo_surgir` e voltam em `ao_veiculo_sair` |
| ocupada | `bool` | Espelhada por `vozes_motor_ocupadas()`; estado lógico sempre coerente com o dicionário |

**Regras de validação**:
- **≤ 1 voz por veículo** (FR-008: "não reproduzir duplicadamente o som do mesmo veículo"): spawn de veículo já registrado ⇒ **no-op** (dicionário é a autoridade).
- Saída de veículo **desconhecido** ⇒ no-op; saída **conhecida** ⇒ `stop()` + devolver à pool + remover do dicionário — **independente do estado** (SC-004: zero som órfão mesmo em recycle durante pausa/vitória).
- Pool de NPCs sem voz livre ⇒ o novo NPC fica **sem som** (silêncio; com o config padrão a pool cobre o teto absoluto de 12 NPCs ativos + 1).
- `play()` **somente** com estado PLAYING **e** `is_inside_tree()` (R2/R4); streams mudo ⇒ no-op.
- Reprodução **contínua** via `loop=true` — nunca `finished` (motores não emitem `finished`, R1).
- **Gate do jogador (FR-003/Clarification Q3)**: a voz 0 (dono `"jogador"`) só reproduz com estado PLAYING **e** `_jogador_acelerando == true`, atualizado pelo forward por quadro `ao_aceleracao_jogador(bool)` (R11); a entrada em PLAYING **não** liga o jogador sozinha — apenas o forward decide; `false` ⇒ `stop()`. NPCs não têm gate (contínuos — FR-002).

## 4. Voz de Colisão (entidade de runtime — `AudioStreamPlayer` da pool)

| Campo | Tipo | Regra |
|-------|------|-------|
| player | `AudioStreamPlayer` | Criado uma vez em `configurar()`; total = `GameConfig.audio_vozes_colisao` (padrão 3) |
| stream | `AudioStreamMP3 \| null` | AUD-001 para **toda** colisão veicular — jogador×NPC **e** NPC×NPC (Clarification Q1/FR-001) |
| livre | `bool` | Lista livre + devolução pelo sinal `finished` (sonda R7) |
| iniciada_em | `int` (`Time.get_ticks_msec`) | Base do roubo LRU quando a pool está exausta (R5) |

**Regras de validação**:
- `tocar_colisao()` faz **exatamente 1 `play()`** por chamada; a razão de "1 chamada por evento" é dos dedups upstream (SPEC-005 cooldown; SPEC-006 dedup por encontro) — o áudio não deduplica (FR-001/SC-002).
- Pool exausta ⇒ roubar a voz **mais antiga** (reiniciar `play()` nela) — todo evento ainda gera sua reprodução (SC-002 100%), sem descartar eventos.
- Gate: estado **PLAYING** e stream não-muda e `is_inside_tree()` (FR-006/SC-007: nunca toca em menu/pausa/vitória).
- Uma colisão **em voo** quando o estado sai de PLAYING é encerrada pelo fluxo da §5 (`stream_paused` na pausa; `stop()` nas saídas) — nunca sobrevive a uma virada (SC-006/SC-007).

## 5. Matriz de Reprodução por Estado (FR-006)

Aplicada **sincronamente** no fim de `_on_state_changed` → `ao_alterar_estado(novo, antigo)` (R4). "Todas as vozes" = jogador + NPCs registrados + colisão em voo.

| Estado de destino | Vozes de motor | Vozes de colisão | Cenário/critério |
|-------------------|----------------|------------------|------------------|
| `PLAYING` | `stream_paused = false` em todas; liga todos os veículos registrados que tenham voz e stream; **jogador só pelo gate** de aceleração (FR-003/Q3) | `stream_paused = false` (se havia uma em voo na retomada) | largada e retomada — SC-006 |
| `PAUSED` | `stream_paused = true` em todas (posição mantida) | `stream_paused = true` | suspender/retomar — Assumption, SC-006 |
| `VICTORY` | `stop()` em todas + `stream_paused = false` | `stop()` + reset | SC-006 / aceite 8 |
| `GAME_OVER` | `stop()` em todas + `stream_paused = false` | `stop()` + reset | SC-006 / aceite 8 |
| `MENU` | `stop()` em todas + reset | `stop()` + reset | SC-007 / aceite 9 |
| `READY` | `stop()` em todas + reset | `stop()` + reset | "não na preparação da largada" (Assumption) |
| desconhecido | `stop()` em todas + reset (**falha segura**) | idem | Qualidade de Código — nunca ficar preso tocando |

Transições relevantes e ordem interna (garantida pelo wiring — [audio_integration.md](contracts/audio_integration.md) §3):

| De → Para | Efeito no áudio |
|-----------|-----------------|
| MENU/READY → PLAYING | `_reset_corrida()` emite os spawns (registrados **parados**) → depois o áudio **liga** os NPCs registrados (o jogador só quando o forward acelerar — Q3) — nenhum som durante a preparação |
| PLAYING → PAUSED → PLAYING | pausa mantém posição; retomada restaura exatamente (SC-006) |
| PLAYING → VICTORY/GAME_OVER | interrompe tudo na mesma virada (SC-006) |
| qualquer → MENU | silencia tudo na virada (SC-007) |
| duas viradas no mesmo quadro | encaminhamento síncrono — **a última virada vence** (edge case do spec, R4) |

**Invariantes globais** (contrato [audio_manager_api.md](contracts/audio_manager_api.md) §3):

1. ≤ 1 player tocando por veículo registrado (FR-008).
2. 0 players tocando para veículos fora do gameplay (SC-004).
3. 1 `play()` de AUD-001 por evento de colisão recebido (SC-002).
4. 0 `play()` de motor fora de PLAYING (FR-006); 0 reproduções em MENU/interfaces (SC-007).
5. 0 nós novos por quadro; pools constantes (RF-004/SC-009).
6. 0 leituras/escritas de velocidade ou multiplicadores (FR-005/SC-005).
7. Efeito com arquivo ausente ⇒ apenas aquele efeito mudo, jogo sem falha (SC-008).
8. Estado lógico sempre coerente mesmo fora da árvore (guarda `is_inside_tree` — R2/SC-009).
9. Voz do jogador só toca em PLAYING com aceleração ativa (FR-003/Q3 — I9 do contrato).

## 6. Configuração (`GameConfig` — bloco `## Áudio (SPEC-010)`)

| Parâmetro | Tipo | Default | Papel |
|-----------|------|---------|-------|
| `audio_colisao_path` | `String` | `res://assets/audio/colisao.mp3` | AUD-001 (FR-004/FR-007) |
| `audio_caminhao_path` | `String` | `res://assets/audio/caminhao.mp3` | AUD-002 |
| `audio_carro_path` | `String` | `res://assets/audio/carro.mp3` | AUD-003 |
| `audio_vozes_colisao` | `int` | `3` | Tamanho da pool de colisão (R5) |
| `audio_volume_motor` | `float` | `0.8` | Volume linear dos motores (R8) |
| `audio_volume_colisao` | `float` | `1.0` | Volume linear da colisão (R8) |
| `audio_categoria_caminhao` | `String` | `"caminhao"` | Id da categoria ⇒ AUD-002 (R6) |

Chave derivada **no orquestrador** (não é campo novo): `vozes_motor = GameConfig.traffic_max_vehicles + 1` (R5 — fonte única da densidade).

## 7. Entidades existentes (intocadas em forma)

| Entidade | Uso pelo áudio | Mudança de schema |
|----------|----------------|-------------------|
| `TrafficData` | lê `id` no nascimento do veículo (R6) | **nenhuma** |
| `TrafficVehicle` | usado como chave do dicionário e para `category.id` | **nenhuma** |
| `CollisionData` / `NpcCollisionData` | payload **ignorado** pelos forwards | **nenhuma** |
| `GameState` | transições só observadas via `_on_state_changed` | **nenhuma** |
| `DifficultyManager` | **nenhuma referência** (FR-005, R10) | **nenhuma** |
