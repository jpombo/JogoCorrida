# Contract — MenuDemo / Ciclo de vida da demonstração (SPEC-012)

Demonstração visual do menu principal (RF-004…RF-011). `Node2D` criado em código pelo `GameplayManager` (research R5/R6); reutiliza como classes `Road`, `BackgroundController`, `DecorationManager` e `TrafficVehicle` com **instâncias próprias**. Nenhum estado de gameplay é lido ou escrito.

## 1. API pública

```gdscript
class_name MenuDemo
extends Node2D

func iniciar() -> void     # reinício consistente: encerra estado anterior, ambiente PLAINS,
                           # pool limpa (≤ demo_npc_max), fade alpha 0, _process = true
func pausar() -> void      # EXECUTANDO ⇒ PAUSADA: mata tween + alpha 0, _process = false
func retomar() -> void     # PAUSADA ⇒ EXECUTANDO: retoma ambiente/tempo pausados
func encerrar() -> void    # de qualquer estado ⇒ PARADA: mata tween + alpha 0, recicla NPCs,
                           # zera rolagem, _process = false; idempotente

func esta_ativo() -> bool          # true só em EXECUTANDO
func ambiente_atual() -> String    # id canônico da sequência ("PLAINS"…), leitura
func npc_ativos() -> int           # veículos da pool atualmente ativos
```

## 2. Regras e invariantes

- **Ciclo de ambientes**: `GameConfig.environment_sequence` (`PLAINS → DESERT → FOREST → ICE`), índice local `% size`, começando **sempre em `PLAINS`** em cada `iniciar()` (RF-005/RF-009). Duração: `demo_duracao_ambiente`.
- **Fade**: um `Tween` por transição sobre um `ColorRect` preto no canvas de mundo (abaixo do `UiLayer` da UI — RF-010): `0→1` em `demo_fade_escurecer` ⇒ troca de ambiente (fundo + decoração) ⇒ `1→0` em `demo_fade_clarear`. A troca acontece com alpha = 1 (**nunca** dois ambientes visíveis). `pausar()`/`encerrar()` matam o tween e forçam alpha 0 (SC-005).
- **NPCs**: pool fixa de até `demo_npc_max` `TrafficVehicle`; reposição a cada `demo_npc_intervalo`; movimento `y += demo_velocidade × delta` (velocidade fixa — **nunca** `DifficultyManager`); reciclagem ao cruzar a borda inferior; X sorteado com separação mínima (`traffic_min_separation`).
- **Isolamento absoluto** (FR-013/FR-018): nunca escreve `GameConfig.current_environment_id`; nunca chama `AudioManager`, combustível, pontuação, progresso, troféus, recordes ou colisão; nunca lê dificuldade.
- **Sem áudio**: a demo não emite sinais de spawn para o orquestrador (os forwards de áudio são exclusivos do `TrafficManager` de corrida) — menu silencioso (Restrições da spec).
- **Desenho**: filho adicionado como **último nó de mundo** do `Gameplay` — acima do cenário de gameplay, abaixo do `UiLayer` (`CanvasLayer`), portanto nunca cobre a interface. **Ordem interna dos filhos espelha o `gameplay.tscn`** — `Background` → `Decoration` → `Road` → NPCs → fade (regressão do aceite T024: Road antes do fundo escondia o asfalto `estrada_2_vias.png` atrás do background; coberta por `menu_demo_test.gd` test_13).

## 3. Pontos de chamada (GameplayManager)

| Momento | Chamada |
|---|---|
| `_ready()` | `menu_demo = MenuDemo.new()` + `add_child` (antes do `_show_menu()` final) |
| `_show_menu()` | `menu_demo.iniciar()` |
| `_show_ready/_playing/_paused/_victory/_game_over` | `menu_demo.encerrar()` |
| sinal `open_settings` | `menu_demo.pausar()` |
| sinal `close_settings` | `menu_demo.retomar()` |

Todos sob guard `if menu_demo:` (testes sintéticos legados).

## 4. Parâmetros lidos do `GameConfig` (FR-022)

`demo_duracao_ambiente`, `demo_fade_escurecer`, `demo_fade_clarear`, `demo_npc_max`, `demo_npc_intervalo`, `demo_velocidade`, `demo_ui_scrim_alpha` + dados já existentes: `environment_sequence`, `ENVIRONMENTS` (`texture_path`), `DECORATION_LIBRARIES`/`DECORATION_PATHS`, `TRAFFIC_CATEGORIES`, limites da pista e `background_multiplier`.
