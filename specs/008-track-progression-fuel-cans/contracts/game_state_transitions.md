# Contrato: Transições de Estado e Ordem de Atualização (SPEC-008)

**Dono das transições**: `src/game/game_state.gd` (`GameState` — existente)
**Orquestrador**: `src/game/gameplay_manager.gd` (`GameplayManager`)
**Observador**: `src/ui/ui_manager.gd` (`UIManager`) — só reage a `state_changed` e emite comandos

---

## 1. Transições exercitadas pela SPEC-008

| Origem → Destino | Gatilho | Guarda |
|---|---|---|
| `PLAYING` → `PAUSED` | `ui_cancel` (Escape) | só em `PLAYING`; zera `road.update_scroll_speed(0)` (FR-004) |
| `PAUSED` → `PLAYING` | comando `continue_race` / `ui_cancel` | rolagem volta a ser alimentada no ramo PLAYING |
| `PLAYING` → `VICTORY` | cruzamento **completo** da banda da chegada + `fuel_atual > 0` + corrida não encerrada | avaliado no passo 6 da ordem canônica; 1× por corrida (`change_state` no-op) |
| `PLAYING` → `GAME_OVER` | `combustível == 0 and speed == 0 and não concluída` (pós-consumo) | 1× por corrida; nunca revertido (ramo PLAYING deixa de rodar; coleta fora de PLAYING não coleta) |
| qualquer → `READY` | `restart_race` / "Tentar novamente" / "Reiniciar" | reset completo orquestrado antes |
| qualquer → `MENU` | `go_to_menu` | reset de encerramento; nenhum sistema avança em segundo plano (FR-036) |

`victory()` e `game_over()` são chamados **apenas** pelo `GameplayManager` (nenhum objeto de gameplay decide estado global — FR-001).

## 2. Ordem canônica do ramo `PLAYING` (FR-017)

1. rolagem da estrada e do fundo;
2. decoração → trânsito → colisão NPC×NPC → limites do jogador → colisão jogador×NPC (hierarquia SPEC-004–006 preservada);
3. galões: movimento → reciclagem → geração → coleta/restauração;
4. combustível: `fuel_system.update(delta, get_speed())`;
5. progressão: `track_manager.update` + marcadores;
6. transições: vitória → senão `GAME_OVER`;
7. flag `aceleracao_bloqueada_por_combustivel` derivada do valor pós-consumo.

Consequências testadas: esgotamento tem precedência no mesmo quadro do cruzamento; coleta no mesmo quadro do esgotamento restaura antes do consumo; coleta nunca reativa `GAME_OVER`.

## 3. Reset (FR-003/FR-035)

- Chamado em três pontos idempotentes: **menu → READY** (`_on_start_race` — T059: indicador em `0,0 km / total` e tanque na carga inicial já no READY), **READY → PLAYING** (nova corrida) e **reinício imediato** (`_on_restart_race` — T022). A entrada em `go_to_menu` não o chama: executa o reset de encerramento embutido (subconjunto: estrada, pista, itens, veículo, trânsito, colisões, decoração e `game_state.reset()`).
- Orquestra `reset()` de: TrackManager, TrackMarkers, FuelSystem (`definir_capacidade_derivada` + `reset`), FuelCanManager, Player/VehicleController, Road, TrafficManager, CollisionSystem, NpcCollisionSystem, DecorationManager e UI.
- Conexões de sinais são feitas **uma única vez** no `_ready`/`setup` — o reset nunca reconecta (SC-012: 0 conexões repetidas, 0 instâncias duplicadas).
- A entrada em `READY` (`_show_ready`) também cria as bandas `INÍCIO`/`CHEGADA` imediatamente — ajuste pós-implementação (Phase 13): antes o jogador só via o quadriculado após o timer de 1 s, quando a virada `READY → PLAYING` recriava os marcadores no reset; a virada continua recriando-os (idempotente).
