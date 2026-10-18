# Contract — Painel de configurações / comandos da UI (SPEC-012)

Tela de configurações do `UIManager` (RF-001/RF-002/FR-001) e mudanças de navegação do menu principal. UI **só exibe e emite** — mutação/persistência/aplicação são do `GameplayManager` (contracts `preferences_manager_api.md` §3).

## 1. Sinais novos (UIManager)

```gdscript
signal open_settings                       # painel de configurações aberto (demo pausa)
signal close_settings                      # voltou ao menu principal (demo retoma)
signal settings_audio_alterado(ativo: bool)
signal settings_resolucao_alterada(resolucao: Vector2i)
```

Conectados no `_ready` do `GameplayManager` (guard `if ui_root:` / `if menu_demo:` / `if preferencias:` / `if audio_manager:` — R9).

## 2. Menu principal — nova linha

`_painel_menu` passa a ter **4 opções** (hoje 3):

| Índice | Linha | Ação com `ui_accept` |
|---|---|---|
| 0 | `Selecionar veículo: <nome>` | `select_next_vehicle` (inalterado) |
| 1 | `Modo: <modo>` | `select_next_mode` (inalterado) |
| 2 | **`Configurações`** (novo) | abre o painel de configurações (emite `open_settings`) |
| 3 | `Iniciar corrida` | `start_race` (inalterado) |

Navegação: `ui_up`/`ui_down` + `wrapi` + `_marcar_opcoes` + `_posicionar_destaque_menu` (4ª faixa de destaque, coordenadas do padrão atual). As mudanças de posição das linhas do menu são as mínimas necessárias para acomodar a 4ª linha — sem redesenho.

## 3. Painel de configurações (`_painel_configuracoes`)

| Índice | Linha | `ui_left`/`ui_right`/`ui_accept` |
|---|---|---|
| 0 | `Áudio: Ligado/Desativado` (`ui_strings.audio_label/audio_on/audio_off`) | alterna → emite `settings_audio_alterado(not atual)` |
| 1 | `Resolução: 640 × 480 / 1024 × 768` (`ui_strings.resolution_*`) | alterna entre `GameConfig.preferencias_resolucoes` → emite `settings_resolucao_alterada(res)` |
| 2 | `Voltar ao menu` (`ui_strings.back_to_menu`) | `ui_accept` ou `ui_cancel` ⇒ fecha o painel (emite `close_settings`) |

Regras:

- Estado exibido inicializado a partir do `PreferencesManager` recebido no `setup(p_track, p_state, p_preferencias = null)` — **3º parâmetro opcional** para preservar as chamadas legadas de 2 argumentos (R9); sem preferências (testes sintéticos), o painel usa os defaults do `GameConfig`.
- O painel só é alcançável a partir do menu principal (Clarificação Q4) — o menu de pausa **não** ganha acesso.
- O menu continua navegável durante o *fade* da demonstração; abrir/fechar configurações pausa/retoma a demo sem reiniciar o ciclo (RF-009, research R6).

## 4. Strings novas (`GameConfig.ui_strings` — §VI)

`settings` ("Configurações"), `settings_title`, `audio_label` ("Áudio"), `audio_on` ("Ligado"), `audio_off` ("Desativado"), `resolution_label` ("Resolução"), `resolution_640` ("640 × 480"), `resolution_1024` ("1024 × 768") — `back_to_menu` e `menu_title` reusados como estão.

## 5. Véu de legibilidade (RF-010)

`_fundo_menu`: `ColorRect` tela cheia com alpha `GameConfig.demo_ui_scrim_alpha`, **primeiro filho** do root da UI (desenha atrás dos textos, acima da demo) — visível apenas nas telas do menu principal/configurações, garante leitura do título/opções sobre qualquer ambiente (SC-008). Calibração em quickstart §5.
