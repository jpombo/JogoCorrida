# Contract — UI de Progressão (SPEC-011)

Extensão da `UIManager` (SPEC-008/009) para exibir pontuação, recorde, acumulada, troféus e estado dos obstáculos — **apenas** no menu inicial e nas telas de vitória/Fim de Jogo (decisão Q3/A, FR-023). Durante a corrida nada muda (continuam o indicador de distância e o HUD de combustível). A UI permanece observadora pura: recebe snapshots; não lê `ProgressManager` nem emite comandos novos.

## 1. API nova da `UIManager`

```gdscript
## Atualiza o bloco de progresso do painel vigente (menu/vitória/game over)
## a partir do snapshot do contrato (data-model §1.5). Idempotente.
func atualizar_painel_progresso(dados: Dictionary) -> void

## Repassada pelo GameplayManager na troca de modo: atualiza a linha "Modo"
## E o ícone de troféu + bloco de progresso do menu (FR-012/SC-006, US2 AS7).
func atualizar_modo(rotulo: String, modo_id: String = "") -> void
```

Sem sinais novos (nenhum comando de UI nasce daqui). `setup()` existente permanece o ponto único de ligação.

## 2. Elementos novos (construídos em código, padrão `_construir_paineis`)

Dentro de **cada** painel (menu, vitória, game over):

| Elemento | Tipo | Conteúdo |
|---|---|---|
| `_icone_trofeu` | `TextureRect` 32×32, NEAREST | `GameConfig.trofeu_assets[modo]` |
| `_rotulo_trofeus` | `Label` | `trophy_format % [trofeus, progresso_k]` — ex.: `2 troféus — Próximo: 3/4 ambientes` |
| `_rotulo_recorde` | `Label` | `record_label` + recorde; no menu, junto da `accumulated_label` (acumulada) |
| `_rotulo_pontuacao` | `Label` | `victory_score % pontuacao` — **só** no painel de vitória (pontuacao > 0) |
| `_rotulo_obstaculos` | `Label` | `obstacles_available` ou `obstacles_locked` |

Layout (640×480, sem sobreposição — SC-012):

- **Menu**: bloco abaixo da linha "Iniciar corrida" (y ≈ 330–420); destaque/menu existente intocado (linhas 0–2 permanecem);
- **Vitória / Game over**: bloco abaixo das opções existentes (y ≈ 240–400); opções e navegação intocadas (FR-020/FR-021 da SPEC-009 preservadas).

Visibilidade segue `_aplicar_estado()` (painel vigente); o indicador de distância não muda.

## 3. Chaves novas de `GameConfig.ui_strings` (FR-026/§VI)

```gdscript
"victory_score":      "Pontuação: %.1f",
"record_label":       "Recorde",
"accumulated_label":  "Acumulada",
"trophy_format":      "%d troféus — Próximo: %d/4 ambientes",
"obstacles_available":"Obstáculos: disponíveis",
"obstacles_locked":   "Obstáculos: bloqueados",
```

> **T042**: a chave `score_label` ("Pontuação da corrida") foi **removida** —
> a pontuação só existe nas telas de vitória/Fim de Jogo, sempre via
> `victory_score` ("Pontuação: %.1f"); menu não exibe bloco de pontuação.

Ícones por modo em `GameConfig.trofeu_assets`:

```gdscript
"relaxing"  → "res://assets/trofeus/trofeu-relaxante.png"
"normal"    → "res://assets/trofeus/trofeu-normal.png"
"challenge" → "res://assets/trofeus/trofeu-desafio.png"
```

## 4. Pontos de chamada (GameplayManager → UI)

| Momento | Chamada |
|---|---|
| `_ready()` (após setup) e `_show_menu()` | `atualizar_painel_progresso(progresso.snapshot(modo))` |
| fim do ramo de vitória (após `processar_vitoria` + save) | `atualizar_painel_progresso(snapshot)` |
| fim do ramo de derrota (após `processar_derrota` + save) | `atualizar_painel_progresso(snapshot)` |
| `_on_select_next_mode` (ciclo do modo) | `atualizar_modo(rotulo, novo_modo_id)` |

O `snapshot` de vitória traz `pontuacao` > 0 (label visível); de derrota/menu traz `pontuacao = -1` (label oculto — FR-003: derrota não tem pontuação de corrida).

## 5. Invariantes

- Zero literais de texto de usuário no script (lê só `ui_strings` — §VI);
- Ícone sempre coerente com o modo exibido — troca junto com a linha "Modo" (SC-006);
- Nenhum componente de UI novo, nenhum nó de cena novo, nenhum elemento em PLAYING/PAUSED/READY;
- `atualizar_painel_progresso` sem snapshot (nulo/{} ou campos faltantes) ⇒ no-op seguro com defaults 0.
