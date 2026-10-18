# Data Model — Menu de Configurações Aprimorado e Menu Principal Dinâmico (SPEC-012)

Fase 1 do `/speckit.plan`. Entidades de domínio em memória, esquema persistido das preferências e máquina de estados da demonstração do menu.

## 1. Entidades de domínio (memória)

### 1.1 Preferências do jogador (`PreferencesManager`)

| Campo | Tipo | Validação | Default |
|---|---|---|---|
| `audio_ativo` | bool | só `true`/`false`; outro tipo ⇒ default | `GameConfig.preferencias_padrao_audio` (`true`) |
| `resolucao` | Vector2i | precisa pertencer a `GameConfig.preferencias_resolucoes` (`[640×480, 1024×768]`) | `GameConfig.preferencias_resolucao_padrao` (640 × 480) |
| `caminho` | String | — | `GameConfig.preferencias_arquivo` (`user://preferencias.json`) |

Regras (FR-007…FR-010, Clarificação Q1):

- **Validação campo a campo** na carga: um campo inválido cai no default **só dele**; os demais campos válidos são preservados (recuperação parcial).
- `carregar()` **nunca grava** (inclusive com arquivo ausente/corrompido — padrão do `SaveManager`); defaults vivem só em memória até a primeira alteração explícita do jogador (edge case da spec: "a próxima alteração regrava um arquivo válido").
- `definir_audio_ativo(v)` / `definir_resolucao(v)` atualizam o campo **e** gravam (uma escrita por alteração — SC-002).
- `salvar() -> bool` delega ao `SaveManager.gravar(dados_para_salvar())` (escrita atômica tmp + rename herdada).

### 1.2 Demonstração do menu (`MenuDemo`) — estado em memória

| Campo | Tipo | Regra |
|---|---|---|
| `_estado` | enum `{PARADA, EXECUTANDO, PAUSADA}` | só transições pela API pública (§3) |
| `_indice_ambiente` | int (0..3) | índice em `GameConfig.environment_sequence`; inicia em `0` (PLAINS) **a cada `iniciar()`** (RF-009) |
| `_tempo_ambiente` | float | acumula `_process` enquanto `EXECUTANDO`; zera a cada troca |
| `_tween_fade` | Tween (nullable) | 1 por transição; morto em `encerrar()`/`pausar()` com alpha forçado a 0 (SC-005) |
| `_npcs` | Array[TrafficVehicle] | pool fixa criada no `iniciar()`, tamanho ≤ `GameConfig.demo_npc_max` (SC-006/SC-007) |
| `_tempo_npc` | float | cronômetro de reposição (`demo_npc_intervalo`) |

Invariantes de isolamento (FR-013/FR-018):

- **Nunca escreve** `GameConfig.current_environment_id` (ambiente da demo é só `_indice_ambiente` → leitura de `ENVIRONMENTS[sequence[i]]`).
- **Nunca** chama combustível, pontuação, progresso, troféus, recordes, colisão ou `AudioManager`.
- **Nunca** lê `DifficultyManager` (velocidade fixa `demo_velocidade` — FR-017).

### 1.3 Veículo NPC da demonstração

Instância normal de `TrafficVehicle` (reuso de sprite/texture-cache, research R5):

| Aspecto | Regra |
|---|---|
| Ativação | `activate(categoria, x, y)` com categoria sorteada de `GameConfig.TRAFFIC_CATEGORIES` |
| Posição X | sorteada dentro de `[road_left_boundary + margem, road_right_boundary − margem]`, rejeitando posições a menos de `traffic_min_separation` de outro NPC ativo (tentativas limitadas; FR-016) |
| Movimento | `y += demo_velocidade × delta` (mesma velocidade da rolagem da estrada; **sem** `fator_dificuldade` — FR-017) |
| Reciclagem | `y > altura_do_viewport + margem` ⇒ `deactivate()` e volta ao pool (FR-016/FR-021) |
| Colisão | inexistente por construção (colisões só rodam em `_processar_playing`) |

## 2. Esquema persistido — `user://preferencias.json` (v1)

```json
{
  "versao": 1,
  "audio": true,
  "resolucao": [640, 480]
}
```

| Chave | Tipo | Regra de carga |
|---|---|---|
| `versao` | int | presente e `== 1` ⇒ esquema conhecido; ausente/diferente ⇒ **todos** os campos default |
| `audio` | bool | inválido ⇒ default |
| `resolucao` | Array[int] de 2 | par fora do conjunto válido ⇒ default (o array é aceito em qualquer ordem; validação por valor) |

Gravação: sempre o esquema v1 completo (dois campos + versão), via `SaveManager` (ataômica). Arquivo separado de `user://progresso.json` (domínio intacto da SPEC-011).

## 3. Máquina de estados da demonstração (`MenuDemo`)

```text
PARADA ── iniciar() ──▶ EXECUTANDO ── encerrar() ──▶ PARADA
                          │  ▲
                          │  │ retomar()
                       pausar() (tela de configurações aberta)
                          ▼  │
                        PAUSADA
```

| Transição | Efeitos |
|---|---|
| `iniciar()` (de qualquer estado) | `encerrar()` interno primeiro (garantia anti-acúmulo); cria/reusa pool (≤ 4), `road.reset()`, `background.reset()`, ambiente `PLAINS`, fade alpha 0, `_process = true` |
| `pausar()` (EXECUTANDO ⇒ PAUSADA) | mata tween ativo + alpha 0; `_process = false`; NPCs e estrada congelados (posição preservada) |
| `retomar()` (PAUSADA ⇒ EXECUTANDO) | `_process = true`; retoma no ambiente/tempo pausados |
| `encerrar()` (de qualquer estado ⇒ PARADA) | mata tween + alpha 0; recicla todos os NPCs (`deactivate`); zera rolagem; `_process = false`; **idempotente** (2ª chamada é no-op) |

Ponto de partida em **todo** `iniciar()` (RF-009/SC-007): `_indice_ambiente = 0`, nenhum NPC ativo, fade limpo — múltiplos ciclos menu ⇄ corrida nunca acumulam objetos nem deixam tela escura.

## 4. Parâmetros centralizados (`GameConfig`, FR-022)

Ver research R8 — blocos `preferencias_*` (4 chaves) e `demo_*` (6 chaves) + 8 chaves novas em `ui_strings`. Nenhum número mágico nos scripts; quickstart §5 define a calibração de `demo_npc_intervalo`, `demo_velocidade` e `demo_ui_scrim_alpha`.

## 5. Snapshot de exibição do painel de configurações (contrato de UI)

```text
{
  "audio_ativo": bool,                 # fonte: PreferencesManager.audio_ativo
  "resolucao": Vector2i,               # fonte: PreferencesManager.resolucao
  "rotulo_resolucao": String           # formatado por ui_strings.resolution_640/1024
}
```

A UI só exibe e emite sinais de alteração (contracts/settings_menu_commands.md); a mutação e a persistência são do orquestrador (contracts/preferences_manager_api.md §3).
