# Contrato: Progressão Infinita de Ambientes e Fluxos de Fim de Corrida (SPEC-009)

**Dono do estado**: `src/game/race_progression.gd` (`RaceProgression` — novo, `RefCounted`)
**Orquestrador**: `src/game/gameplay_manager.gd` (`GameplayManager`)
**Dados**: `GameConfig.environment_sequence`, `GameConfig.difficulty_cycle_bonus_increment`, `GameConfig.current_environment_id`
**Transições de estado**: `GameState` (autoload — inalterado; nenhuma transição nova)
**Referências**: [data-model.md](../data-model.md) §4, research R9/R10, [ui_commands.md](./ui_commands.md)

## 1. Sequência

`GameConfig.environment_sequence = ["PLAINS", "DESERT", "FOREST", "ICE"]` — cicla com `% 4` (FR-019). A troca de ambiente usa a **propagação existente**: escrever `GameConfig.current_environment_id` e o `GameplayManager._process` detecta por quadro e chama `_propagar_ambiente` (fundo + decoração) — sem sinal novo, sem mudança em `EnvironmentManager` (R9).

## 2. Regras de progressão (FR-019/FR-022/FR-023)

| Evento | Chamada | Efeito |
|--------|---------|--------|
| Vitória (`_avaliar_transicoes`, antes de `game_state.victory()`) | `progresso.registra_vitoria()` | `vitorias+1`; se `==4`: `ciclos+1`, `vitorias=0`; `posicao=(pos+1)%4` |
| Derrota (`_avaliar_transicoes`, antes de `game_state.game_over()`) | `progresso.zerar_ciclo_por_derrota()` | `posicao=0`, `vitorias=0`; **`ciclos` preservado** |
| Início de corrida (menu→READY, "Continuar próxima fase") | `GameConfig.current_environment_id = progresso.ambiente_atual()` | ambiente da próxima corrida; depois `_reset_corrida()` + `start_game()` |
| Refresh por corrida (mesmo `_on_start_race`/`_on_continue_next_phase`) | `dificuldade.aplicar_fator_ciclo(progresso.fator_ciclo())` | fator de ciclo novo na configuração efetiva |
| Reiniciar (pausa) | nenhuma chamada de progressão | mesma corrida, mesmo ambiente, mesmo fator |

## 3. Fluxos de fim de corrida (FR-020/FR-021 — substituem o "Tentar novamente" da SPEC-008)

| Tela | Opções (ordem) | Sinais emitidos | Handler no GameplayManager |
|------|----------------|-----------------|---------------------------|
| Vitória | 1. Continuar próxima fase; 2. Voltar ao menu | `continue_next_phase`; `go_to_menu` | `_on_continue_next_phase`; `_on_go_to_menu` |
| Fim de jogo | 1. Voltar ao menu | `go_to_menu` | `_on_go_to_menu` |
| Pausa (inalterada) | Continuar; Reiniciar; Voltar ao menu | `continue_race`; `restart_race`; `go_to_menu` | handlers existentes |

`_on_continue_next_phase`:
1. `GameConfig.current_environment_id = progresso.ambiente_atual()` (avanço já registrado na vitória);
2. `dificuldade.aplicar_fator_ciclo(progresso.fator_ciclo())`;
3. `_aplicar_sprite_selecionado()` + `_reset_corrida()` + `game_state.start_game()` — mesmo preparo do `_on_start_race`.

`_on_go_to_menu` (após derrota): o `zerar_ciclo_por_derrota()` já rodou — a próxima largada pelo menu nasce em PLAINS com ciclos preservados (R9).

## 4. Bônus de ciclo (FR-022)

`fator_ciclo = 1 + GameConfig.difficulty_cycle_bonus_increment × ciclos_concluidos` — semente `0,002` (0,2% por ciclo completo). Velocidade efetiva = `velocidade_base × multiplicador_modo × fator_ciclo` (SC-016). Ciclo 1 = 1,000 (nenhum bônus). Configurável; aplicado na largada, nunca no meio da corrida.

## 5. Garantias

1. Progresso vive **apenas na sessão** — fechar o jogo zera posição, vitórias e ciclos (FR-023; persistência fora do escopo).
2. "Continuar" mantém o modo selecionado e prepara a corrida do zero (reset SPEC-008 — tanque na carga inicial, distância zerada).
3. Nenhum objeto de gameplay decide estado global: vitória/derrota continuam exclusivas do `_avaliar_transicoes` → `GameState` (FR-001 herdados).
4. A sequência nunca repete ambiente como "próxima fase" (avanço % 4); derrota em qualquer ponto recomeça por PLAINS.
