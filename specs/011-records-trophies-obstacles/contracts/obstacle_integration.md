# Contract — Integração dos Obstáculos (SPEC-011)

Fio de montagem entre `ObstacleManager`/`Obstacle` (novos), `GameplayManager` (orquestrador), `VehicleController` (efeitos), `FuelSystem` (acumulador de perda) e `GameConfig` (parâmetros). Padrão de referência: `FuelCanManager` + `FuelCan` (SPEC-008).

## 1. Componentes novos

### 1.1 `src/obstacles/obstacle_manager.gd` — `ObstacleManager extends Node2D`

```gdscript
## Criado em _ready() pelo GameplayManager (add_child), como o items_layer.
func configurar() -> void                                # monta a pool (guardado: idempotente)
func definir_disponivel(flag: bool) -> void              # gate por corrida (FR-018/FR-019)
func reset() -> void                                # devolve pool, zera distância integrada; mantém o gate
func update(delta: float, road, npcs: Array, track, player) -> void
```

`update` é chamado pelo `GameplayManager` como **passo 3.5 do ramo PLAYING, imediatamente após os galões** (passo 3) e antes do combustível (passo 4) — mesma posição relativa que os galões ocupam (antes do consumo), ordem canônica documentada em `_processar_playing`. Sem `player`/`road`/`track` (nulos) ⇒ no-op (guards de teste sintético).

Responsabilidades (todas configuráveis — FR-026):

1. **Movimento**: rolagem dos ativos por `road.scroll_speed` (px/s), reciclagem ao cruzar a base da tela;
2. **Spawn por distância**: `distancia_desde_ultima += maxf(velocidade_do_jogador, 0.0) × GameConfig.track_units_to_km × delta` (km; `velocidade` = `player.get_speed()`, com fallback `road.scroll_speed / scroll_multiplier` — `_velocidade_do`); ao cruzar `GameConfig.obstaculo_intervalo_km` sortear `"poca"|"cascalho"` pelos pesos e posicionar;
3. **Validação** (pesquisa R6): limites da pista + margem do sprite; faixa start/finish offset (idênticos aos galões); `obstaculo_min_spacing` de outros obstáculos; retângulo do obstáculo **crescido por `obstaculo_npc_spacing`** contra `get_occupied_area()` de qualquer NPC do snapshot (área 2D, não só o eixo Y); caixa contra o hitbox do jogador. Falha ⇒ candidato fica **pendente** e é revalidado **a cada quadro** (mesmo X/tipo) até nascer ou **expirar em `2 × intervalo`** (a integra zera) — nunca gerar inválido, nunca descartar cedo;
4. **Detecção** (research R3; ajuste T032): AABB por quadro — `item.area_contato()` (derivada de `obstaculo_tamanho_*`) contra o retângulo do jogador (`GameConfig.player_hitbox_size`) — **cascalho** ⇒ `player.controller.aplicar_efeito_cascalho(...)` com os parâmetros do config + reciclagem imediata (renova por sobrescrita se o efeito já está ativo, FR-016); **poça** ⇒ desvio lateral único `player.position.x ± GameConfig.poca_desvio_lateral` para o lado da posição do impacto (`player.x <= item.x` ⇒ esquerda, senão direita), clamp nas bordas da pista ± meia largura do carro, e estado `ATINGIDO` — a poça permanece visível e inerte na pista, sem novo desvio, até ser reciclada ao cruzar a base;
5. **Gate**: `disponivel == false` ⇒ nenhum spawn (obstáculos já ativos continuam rolando até sair — em prática o gate é definido no reset, antes de qualquer spawn).

Sem interação com combustível, NPCs ou decoração (FR-014/FR-015/RF-005).

### 1.2 `src/obstacles/obstacle.gd` — `Obstacle`

Sprite + hitbox explícito derivado de `GameConfig.obstaculo_tamanho_*` (48×35 poca, 48×27 cascalho). Sem `_process` próprio, sem `Area2D` — geometria pura testável (mesma política dos galões).

## 2. `VehicleController` — efeito temporizado do cascalho (research R5)

```gdscript
## Cascalho — teto de velocidade reduzido; estabilidade opcional (fator 1,0 = desligada).
func aplicar_efeito_cascalho(duracao: float, fator_velocidade: float, fator_aderencia: float) -> void
```

- **Poça não passa pelo controlador** (ajuste T032): o desvio lateral é aplicado pelo `ObstacleManager` direto na posição do jogador (§1.4) — nenhum campo de efeito da poça existe mais no veículo;
- Tick no `_process` do controlador (parado fora de PLAYING via `PlayerVehicle.set_process` — congelamento na pausa por construção, FR-016);
- Renovação por sobrescrita (nunca soma tempo nem intensidade);
- Cascalho: enquanto ativo, `speed = min(speed, max_speed × dificuldade.fator_velocidade_total() × fator)` a cada quadro; estabilidade via `efeito_aderencia_cascalho`;
- `reset()` (já chamado pelo `PlayerVehicle.reset`) limpa o efeito junto com o restante.

Parâmetros do cascalho passados pelo `ObstacleManager` vêm sempre de `GameConfig` (`cascalho_*`); o desvio da poça usa `GameConfig.poca_desvio_lateral` no próprio `ObstacleManager` — o controlador não conhece obstáculos.

## 3. `FuelSystem` — acumulador de perda por colisão (research R4)

```gdscript
var perda_colisao_corrida: float = 0.0   # zeroado em reset()
func get_perda_colisao_corrida() -> float
```

`on_player_collision(impulso)` soma o **delta real** descontado (`antes − _atual` após clamp, já com `dificuldade.fator_penalidade_colisao()`). Consumo normal (`update`) nunca toca no acumulador. O ramo de vitória lê `get_perda_colisao_corrida()` — nenhuma conta duplicada no orquestrador.

## 4. `GameplayManager` — wiring

| Ponto | Ação |
|---|---|
| `_ready()` | `progress_manager = ProgressManager.new()`; `save_manager = SaveManager.new()`; `obstacles_layer = ObstacleManager.new(); add_child(...); obstacles_layer.configurar()`; carga dos dados (`progress_manager.carregar_de(save_manager.carregar())`) |
| `_processar_playing` passo 3.5 | `if obstacles_layer and road: obstacles_layer.update(delta, road, traffic snapshot, track_manager, player_vehicle)` |
| `_avaliar_transicoes` vitória | captura `ambiente` → `progresso_corrida.registra_vitoria()` → `progresso.processar_vitoria(modo, ambiente, distancia, perda_colisao)` → `save.gravar(...)` **1×** → UI/emit |
| `_avaliar_transicoes` derrota | `progresso.processar_derrota(modo)` → `save.gravar(...)` **1×** → UI/emit |
| `_reset_corrida()` | `obstacles_layer.reset()`; `obstacles_layer.definir_disponivel(progresso.obstaculos_disponiveis(dificuldade.get_modo()))` |
| `_avaliar_transicoes` vitória/derrota (ramos de encerramento) | `obstacles_layer.reset()` — mesmos pontos que já limpam `items_layer` (FR-023) |
| `_on_go_to_menu()` | `obstacles_layer.reset()` junto com `items_layer.reset()` (FR-023 + US4 AS9) |
| `_show_menu()` / `_show_ready()` | `obstacles_layer.visible = false` / `true` (espelha `items_layer`) |
| `_show_menu()` / `_avaliar_transicoes` (pós-gravação) / `select_next_mode` | snapshot para `ui.atualizar_painel_progresso(...)` (menu, vitória, game over) — contrato da UI §4 |

Todos os campos novos iniciam `null` com guards `if ...` — testes sintéticos legados intocados (research R12).

## 5. `GameConfig` — blocos novos

`score_*`, `poca_desvio_lateral`, `cascalho_*`, `obstaculo_*`, `trofeu_assets`, `obstaculo_poca_path/cascalho_path`, `obstaculo_tamanho_poca/cascalho`, `save_arquivo`, chaves novas de `ui_strings` (contract da UI §3). Sementes: research R13. Nenhum parâmetro da SPEC-009 é alterado (FR-025).
