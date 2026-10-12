# Contrato: Comandos e Observação da UI (SPEC-008)

**Emissor**: `src/ui/ui_manager.gd` (`UIManager`)
**Consumidor**: `src/game/gameplay_manager.gd` (comandos) + sistemas observados (_track/fuel/estado_)
**Textos**: 100% de `GameConfig.ui_*` — nenhum literal de usuário no script (FR-041, §VI)

---

## 1. Comandos (sinais emitidos pela UI)

| Sinal | Origem na UI | Ação do GameplayManager |
|---|---|---|
| `start_race` | opção "Iniciar corrida" do menu (após `ui_up`/`ui_down` destacá-la) | aplica veículo selecionado → `GameState.start_game()` |
| `select_next_vehicle` | `ui_left`/`ui_right` no menu (alterna azul ↔ vermelho) | alterna `azul` ↔ `vermelho` e chama `player_vehicle.change_sprite` |
| `continue_race` | "Continuar" na pausa | `GameState.resume_game()` |
| `restart_race` | "Reiniciar" (pausa) / "Tentar novamente" (fim) | reset orquestrado → `GameState.start_game()` |
| `go_to_menu` | "Voltar ao menu" (pausa/fim) | reset de encerramento → `GameState.reset()` (MENU) |

Regras: a UI **nunca** chama `GameState` diretamente nem escreve em gameplay (FR-005); os rótulos "Continuar"/"Reiniciar"/"Tentar novamente"/"Voltar ao menu" são os mesmos das telas (FR-034).

## 2. Observação

| Fonte | Sinal | Efeito na UI |
|---|---|---|
| `GameState` | `state_changed` | mostra/esconde: `MenuPanel` (MENU), `PausePanel` (PAUSED), `VictoryPanel` (VICTORY), `GameOverPanel` (GAME_OVER); em READY/PLAYING só o indicador de distância (+ FuelHud da SPEC-007) |
| `TrackManager` | `progress_changed` | rótulo do template `ui_distance_format` + largura da barra (`percentual`); congela quando os emissions param (pausa/fim) |

## 3. Entrada

- Ações já existentes: `ui_accept` (confirmar), `ui_cancel` (pausar/continuar), `ui_up`/`ui_down`/`ui_left`/`ui_right` (navegar/selecionar veículo).
- No menu, `ui_up`/`ui_down` alternam entre as duas opções ("Selecionar veículo" + nome, "Iniciar corrida"); a opção ativa recebe um retângulo semitransparente de destaque, e `ui_accept` só emite `start_race` com "Iniciar corrida" destacada (ajuste pós-implementação — Phase 13).
- Em `PAUSED`, `ui_cancel` continua = Continuar (atalho atual preservado).
- Nenhum controle novo de gameplay (§I); a UI ignora entradas em estados sem painel ativo.

## 4. Garantias de teste

- Painéis e textos refletem 100% dos estados em 100% das transições (SC-017).
- Observador puro: nenhum caminho da UI escreve em Track/Fuel/Player/Estado (SC-015).
- Seleção de veículo: padrão `azul` no boot; atributos de gameplay idênticos entre veículos (SC-001).
