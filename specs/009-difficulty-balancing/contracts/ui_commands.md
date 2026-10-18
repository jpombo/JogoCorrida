# Contrato: Comandos de UI — Menu (Modo) e Telas de Fim (SPEC-009)

**Dono**: `src/ui/ui_manager.gd` (`UIManager` — extensão do SPEC-008; ver também `specs/008-track-progression-fuel-cans/contracts/ui_commands.md` para o contrato base)
**Observador/emissor**: só reage a input e a `state_changed`; emite comandos — nunca escreve em gameplay (FR-005/008 herdados)
**Textos**: exclusivamente `GameConfig.ui_strings` (§VI — zero literal no script)

## 1. Menu inicial — 3 linhas (FR-016, placeholder da SPEC-013)

| Linha | Rótulo (chave `ui_strings`) | `ui_accept` | Sinal |
|-------|-----------------------------|-------------|-------|
| 0 | `select_vehicle` + nome (`vehicle_blue`/`vehicle_red`) | alterna veículo | `select_next_vehicle` |
| 1 | `mode_label` + nome do modo (`mode_relaxing`/`mode_normal`/`mode_challenge`) | cicla modo | `select_next_mode` |
| 2 | `start_race` | inicia corrida | `start_race` |

- Navegação `ui_up`/`ui_down` com `wrapi(0, 3)`; destaque semitransparente existente reposicionado (padrão Phase 13 da SPEC-008).
- Estado do modo fica no `DifficultyManager` (cicla via `ciclar_modo()`); a UI só exibe o rótulo recebido — sincronização: `_on_select_next_mode` no `GameplayManager` chama o DifficultyManager e devolve o rótulo via `ui_root.atualizar_modo(rotulo)`.

## 2. Novas chaves de `ui_strings`

| Chave | Valor padrão (pt-BR) |
|-------|----------------------|
| `mode_label` | `Modo` |
| `mode_relaxing` | `Relaxante` |
| `mode_normal` | `Normal` |
| `mode_challenge` | `Desafio` |
| `continue_next_phase` | `Continuar próxima fase` |

(`victory`, `game_over`, `back_to_menu` já existem na SPEC-008.)

## 3. Sinais (base SPEC-008 + novos)

| Sinal | Estado | Mudança na SPEC-009 |
|-------|--------|---------------------|
| `start_race` | MENU | inalterado |
| `select_next_vehicle` | MENU | inalterado |
| `select_next_mode` | MENU | **NOVO** — cicla o modo no DifficultyManager |
| `continue_race` | PAUSED | inalterado (vitória deixa de usá-lo) |
| `restart_race` | PAUSED | inalterado (vitória/Game Over deixam de usá-lo) |
| `continue_next_phase` | VICTORY | **NOVO** — avança a sequência e inicia a próxima corrida |
| `go_to_menu` | PAUSED/VICTORY/GAME_OVER | inalterado (Game Over passa a ser o único caminho da tela) |

## 4. Telas de fim (FR-020/FR-021 — substituem FR-034 da SPEC-008)

| Tela | Opções (ordem do menu) | Navegação | Sinal por opção |
|------|------------------------|-----------|-----------------|
| Vitória | `continue_next_phase`, `back_to_menu` | `ui_up`/`ui_down` + `ui_accept` | 0→`continue_next_phase`, 1→`go_to_menu` |
| Fim de jogo | `back_to_menu` | `ui_accept` | 0→`go_to_menu` |

- "Tentar novamente"/"Reiniciar" **removidos** das telas de vitória e Game Over (reinicio por derrota só via menu — regra Q1-A/Q2-B).
- Pausa permanece com `continue_race`/`restart_race`/`go_to_menu` (inalterado); o ESC ganhou **guarda de quadro** em 2026-10-14 (não retoma/pausa no mesmo quadro da virada de estado — ver `specs/008-track-progression-fuel-cans/contracts/ui_commands.md` §3, regressão em `tests/unit/pause_esc_test.gd`).

## 5. Exibição do modo (FR-017)

- Menu: linha 1 sempre reflete o modo vigente (inclusive após `select_next_mode`).
- O rótulo do modo pode ser exibido na largada quando necessário — exigência mínima satisfeita pela linha do menu; nenhuma tela de HUD nova é exigida por esta spec.
