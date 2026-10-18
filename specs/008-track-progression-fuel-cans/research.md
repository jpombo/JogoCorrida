# Research — Progressão da Pista, Estados, Combustível e Galões (SPEC-008)

**Data**: 2026-10-10 | **Base**: `spec.md` (41 FR, 17 SC, 10 Clarifications) + Constituição v3.0.0 + código das SPEC-001–007

Cada decisão abaixo resolve uma questão aberta do plano com **raciocínio, alternativas descartadas e referências verificáveis**. Itens marcados como **CALIBRAÇÃO** têm valores-semente propositalmente provisórios — o ajuste fino é tarefa explícita do plano (FR-039, SC-016).

---

## R1 — TrackManager: integração da distância pela velocidade de avanço (FR-006/FR-007, Clarification de faixa)

**Decisão**: novo componente `src/track/track_manager.gd` (`class_name TrackManager extends Node`) com:

```
update(delta, velocidade_avanco):
    if estado != PLAYING: return                 # só o ramo PLAYING chama (research R9)
    percorrida = minf(percorrida + velocidade_avanco * GameConfig.track_units_to_km * delta, total)
    restante   = total - percorrida
    percentual = (total > 0) ? percorrida / total : 1.0
    emit progress_changed(...) apenas em variação real
```

- **`velocidade_avanco` = `player_vehicle.get_speed()`** — exatamente a fonte que impulsiona a rolagem (`road.update_scroll_speed`); mudança de faixa (`lateral_speed`) nunca entra (Clarification 2026-10-10: "não cresce").
- **`track_units_to_km`**: `@export` com semente derivada de `KMH_TO_SPEED_UNIT` (SPEC-004): `1 un/s = 1/KMH_TO_SPEED_UNIT km/h = 1,25 km/h` ⇒ `km = un × (1,25/3600) × delta`. Semente `0.00034722` (**CALIBRAÇÃO**); em velocidade máxima (100 un/s = 125 km/h) a pista de 5,0 km leva ≈ 144 s.
- `percorrida` é monotônica não-crescente e limitada ao total **por construção** (`minf`), inclusive na virada para zero (SC-003/SC-004).
- **Não usar `road.scroll_offset`** como fonte: ele é interno à estrada (reciclagem de segmentos, freeze/collapse de estado) e a spec exige independência da reciclagem (FR-007); integrar a velocidade dá o mesmo valor com fonte explícita e teste unitário sem a árvore de cena.

**Alternativas descartadas**:
- *Distância = `scroll_offset` convertido* — rejeitado: acopla à estrada, sobrevive a resets parciais de scroll e complica o teste sem cena.
- *Distância por posição vertical do sprite* — rejeitado: proibido explicitamente (FR-007).
- *Distância por temporizador × velocidade_máxima* — rejeitado: parado não pode acumular (SC-003).

**Referências**: `src/game/gameplay_manager.gd:139` (`update_scroll_speed(get_speed())`), `src/player/player_vehicle.gd:70`, `src/config/game_config.gd:75` (`KMH_TO_SPEED_UNIT = 0.8`), `src/road/road.gd:197`.

---

## R2 — Chegada: marcador no mundo, posicionado uma vez e movido pela rolagem; vitória geométrica (FR-011/FR-013, caso de borda 14)

**Decisão**: a `CHEGADA` é um `Node2D` filho de `TrackMarkers` (`src/track/track_markers.gd`), criado no início da corrida em `y = player_y − total / track_units_to_km` (≈ 14.400 px acima para 5,0 km) e movido a cada quadro por `y += road.scroll_speed × delta` — a **mesma lógica de rolagem** da estrada (FR-011). A banda quadriculada é construída com `ColorRect` (sem sprite novo). A vitória é avaliada por geometria:

```
cruzou_completamente = banda.top_y >= player.base_y   # banda inteira abaixo da base do carro
```

com as quatro condições de FR-013 no instante (`PLAYING`, combustível > 0, cruzou, corrida não encerrada). A `percorrida` pode chegar ao total antes do cruzamento completo (caso de borda 14): a distância fica limitada ao total, mas a banda **continua descendo com a rolagem** e o cruzamento se completa em seguida — a vitória depende do cruzamento efetivo, não do valor.

- O `INÍCIO` nasce na posição do player no início da corrida, desce com a rolagem e, ao sair completamente da tela, é ocultado definitivamente (FR-010) — sem lógica de reaparecimento.
- Rótulos `INÍCIO`/`CHEGADA` vêm de `GameConfig` (§VI/FR-041).

**Alternativas descartadas**:
- *Vitória quando `percorrida >= total`* — rejeitado: contradiz o caso de borda 14 ("a vitória depende do cruzamento efetivo, não apenas do valor").
- *Marcador re-spawnado por faixa de distância restante* — rejeitado: posicionamento único + rolagem é mais simples, determinístico e idêntico visualmente; evita estados de reaparecimento.
- *Mapear restante → `y` por quadro* — rejeitado: com `percorrida` capada em `total`, o marcador nunca passaria do jogador e o cruzamento completo seria impossível.

**Referências**: `src/road/road.gd:122–128` (mover por `scroll_speed × delta`), spec FR-010/FR-011/FR-013, casos de borda 2/3/14.

---

## R3 — Dimensionamento do combustível: override explícito antes do `reset()` (FR-018/FR-019, Clarification de capacidade)

**Decisão**: no início da corrida (transição **READY → PLAYING**, junto ao reset existente):

```
estimado = track_total_distance × GameConfig.fuel_consumption_per_distance + GameConfig.fuel_safety_margin
fuel_system.definir_capacidade_derivada(estimado)   # novo método público
fuel_system.reset()                                  # comportamento SPEC-007 preservado
```

- `FuelSystem` ganha `var _capacidade_derivada: float = -1.0` e `definir_capacidade_derivada(cap)`: grava `maxf(cap, 0.0)` ou volta a `-1.0` (sentinela de "sem override"). No `reset()`, `_capacidade = maxf(derivada se ≥ 0, senão GameConfig.fuel_capacity, 0.0)` — o caminho atual das suítes SPEC-007 **não muda** (sem chamada ⇒ sem override).
- A partida continua nascendo cheia: `fuel_initial_amount = -1` ⇒ `inicial = capacidade` (SPEC-007/FR-018).
- **Semente CALIBRAÇÃO**: `fuel_consumption_per_distance = 40.0` un/km, `fuel_safety_margin = 60.0`, `track_total_distance = 5.0` km ⇒ capacidade provisória `260` un (corrida de referência ≈ 144 s a 125 km/h com consumo médio ≈ 1,3 un/s ≈ 187 un — sobra ≈ 73 un ≈ 28%). Faixa de calibração-alvo: sobra de 15%–35% na corrida sem colisões nem coletas (SC-006).
- `combustivel_estimado` e `capacidade` são o **mesmo valor** (partida cheia — spec US5/FR-018), sem segunda fonte: alterar `track_total_distance` muda o tanque automaticamente (SC-016).

**Alternativas descartadas**:
- *Reescrever `GameConfig.fuel_capacity` por corrida* — rejeitado: mutaria o autoload global (fonte compartilhada com testes e com o valor nominal da SPEC-007).
- *Capacidade fixa calibrada para a maior pista* — rejeitado: contradiz a Clarificação "capacidade derivada em tempo de execução".
- *Novo `reset(capacidade)`* — rejeitado: quebraria a assinatura consumida pelas 6 suítes `fuel_*` (contrato SPEC-007); override separado é aditivo e testável.

**Referências**: `src/fuel/fuel_system.gd:33–43` (reset), `specs/007-fuel-system/contracts/consumed_apis.md`, Clarifications 2026-10-10 (Q1/Q2).

---

## R4 — Restauração por coleta: interface pública `restaurar(valor)` (FR-024/FR-025/FR-033/FR-038)

**Decisão**: `FuelSystem.restaurar(valor: float) -> void`:

```
if capacidade <= 0: return
_novo = clampf(_atual + maxf(valor, 0.0), 0.0, _capacidade)
_escrever(_novo)          # emite fuel_changed apenas em variação real (tanque cheio ⇒ no-op silencioso)
```

- Reaproveita `_escrever`: cap cheio não emite variação; **não** rearma nem dispara `fuel_depleted` (restauração nunca esgota; o latch fica como estava — Clarificação "sem rearme").
- Com `_atual == 0` a restauração escreve normalmente (o `update()` é que é no-op em zero, consumidor continua bloqueado pela flag de R5 até o valor voltar a ser positivo).
- Só o `FuelCanManager`/`GameplayManager` chamam `restaurar` — a autoridade sobre quantidade/capacidade/eventos permanece no FuelSystem (FR-033/FR-038); nenhum componente escreve `_atual` diretamente.

**Alternativas descartadas**:
- *`update()` com "delta positivo"* — rejeitado: sobrecarrega semântica de consumo e confunde o contrato SPEC-007.
- *Gerenciador de galões emitindo `fuel_changed`* — rejeitado: quebra FR-033 (autoridade exclusiva) e SC-015.

**Referências**: `src/fuel/fuel_system.gd:99–108` (`_escrever`), `specs/007-fuel-system/contracts/fuel_events.md`.

---

## R5 — Bloqueio de aceleração com combustível zero: flag derivada no `VehicleController` (FR-015, SC-007)

**Decisão**: `VehicleController` ganha `var aceleracao_bloqueada_por_combustivel: bool = false`, checada **em conjunto** com o lockout da SPEC-005:

```gdscript
Input.is_action_pressed("accelerate") and not brake
    and aceleracao_bloqueada <= 0.0
    and not aceleracao_bloqueada_por_combustivel
```

- `GameplayManager` atualiza a flag a cada quadro do ramo `PLAYING` após o consumo: `controller.aceleracao_bloqueada_por_combustivel = fuel_system.get_atual() <= 0.0`; limpa em `reset()`.
- Frenagem e desaceleração natural continuam valendo (FR-015: "não para instantaneamente"); coleta que restaura o valor **desbloqueia no mesmo instante** em que a flag é recalculada — o bloqueio deriva do valor atual, não de latch (Clarificação Q2/FR-017).
- Distinta e independente de `aceleracao_bloqueada` (temporizada da SPEC-005): as duas podem coexistir sem interferir.

**Alternativas descartadas**:
- *Congelar `accelerate` no `Input`* — rejeitado: global, afetaria outros consumidores e sairia do modelo de estado do veículo.
- *Latch "esgotado" como bloqueio* — rejeitado: contradiz a Clarificação "sem rearme" (a coleta deve desbloquear sem novo evento).
- *`GameplayManager` ignorar o input* — rejeitado: o input é aplicado dentro do controller; duplicar a lógica de física vertical espalharia a regra.

**Referências**: `src/player/vehicle_controller.gd:47–57`, `src/game/gameplay_manager.gd:185–186`, SPEC-005 (lockout), spec FR-015/FR-017.

---

## R6 — Gerenciador de galões dedicado (análise obrigatória do FR-027)

**Decisão**: módulo novo `src/items/` com `FuelCanManager` (Node2D, pool estilo `TrafficManager`) + `fuel_can.gd` (Node2D com `Sprite2D` + área de contato). **Análise exigida pelo FR-027**:

- **Reintegrar ao `TrafficManager`** — descartado: o trânsito é dominado de veículos (categorias, velocidades relativas, drift, janelas NPC×NPC, validadores SPEC-006); galões são itens com ciclo próprio (coleta, restauração, piso/teto por corrida, "não é colisão"). Misturaria responsabilidades incompatíveis (constituição §III, FR-027) e colocaria gameplay de item no caminho crítico de colisões.
- **Reusar `DecorationManager`** — descartado: decoração é ambiental, amarrada a biblioteca por ambiente, sem ciclo de interação e sem autoridade de gameplay; FR-022 exige superfície dirigível e validação contra NPCs.
- **Componente próprio** — escolhido: mesma arquitetura de "pool + update(delta, road)" já consolidada, sinais `fuel_can_spawned`/`fuel_can_collected` (FR-032), dependências apenas de leitura de `Road`/snapshot do trânsito/`GameConfig`, testável sem a árvore.

**Referências**: `src/traffic/traffic_manager.gd:1–62`, `src/decoration/decoration_manager.gd`, constituição §III, FR-027.

---

## R7 — Geração dos galões: distância com taxa por ambiente e piso/teto por corrida (FR-028/FR-029/FR-030, Clarifications)

**Decisão**: em `FuelCanManager.update(delta, road, snapshot_npcs, track, player)` apenas no ramo `PLAYING` e com `road.scroll_speed > 0` (parado, nada nasce — coerente com a Clarificação de velocidade e com SC-022 do trânsito):

```
distancia_desde_ultima += speed × track_units_to_km × delta
intervalo_efetivo      = fuel_can_spawn_interval_distance / spawn_rate[ambiente]
candidato_valido       = distancia_desde_ultima >= intervalo_efetivo
                         and ativos.size() < fuel_can_max_active
                         and gerados_na_corrida < fuel_can_max_per_race
                         and percorrida >= fuel_can_start_offset
                         and restante  >= fuel_can_finish_offset
                         and (gerados_na_corrida >= fuel_can_min_per_race
                              or distancia_desde_ultima >= intervalo_efetivo × 0.5)  # piso: antecipa
posição_x              = uniforme entre (left+margin) e (right−margin) nos limites vigentes
validação              = sem interseção com NPCs do snapshot (retângulo inflado por fuel_can_npc_spacing)
                         e sem interseção com galões ativos (fuel_can_min_spacing em qualquer eixo)
```

- **Taxa por ambiente** (`fuel_can_spawn_rate`, semente **CALIBRAÇÃO**): `PLAINS 1.4, DESERT 1.0, FOREST 0.7, ICE 0.5` — ordem planície > deserto > floresta > gelo por construção (SC-010), proporcional à dificuldade do `ENVIRONMENTS`.
- **Piso/teto por corrida** = `fuel_can_min_per_race`/`fuel_can_max_per_race` sobre o **total gerado** (Clarificação: `min 4`, `max 12`, sementes); o piso antecipa o spawn quando a corrida está abaixo do mínimo e o teto corta novas gerações (reciclagem de não coletados continua valendo — não conta como nova geração).
- Posição inválida ⇒ **adiar para o próximo quadro** (nunca descartar o candidato até o próximo intervalo — espelha o `_spawn_pendente` do trânsito, FR-030).
- O spawn usa os **limites vigentes da estrada** no topo da tela (`road.left_boundary/right_boundary`) — em trechos de 4 vias a pista é maior, então o intervalo por distância permanece válido nas transições (caso de borda 18).

**Alternativas descartadas**:
- *Spawn por temporizador* — rejeitado: FR-028 proíbe depender exclusivamente de temporizadores (velocidade variável quebraria a distribuição).
- *Spawn relativo ao scroll em px* — rejeitado: a spec dimensiona tudo em unidades de distância da corrida (consistência com `TrackManager`).
- *Revalidar retroativamente galões já spawnados em transição de faixa* — rejeitado: fora de escopo (dívida conhecida da SPEC-004 também não faz); validação é no nascimento.

**Referências**: `src/traffic/traffic_manager.gd:99–120` (guardas de spawn), spec FR-028–FR-030, Clarifications 2026-10-10.

---

## R8 — Coleta: sobreposição própria, sem pipeline de colisão (FR-024, Clarification de colisão)

**Decisão**: detecção dentro do `FuelCanManager`, no final do quadro de PLAYING **antes** do consumo (ordem da spec: detecção → coleta → combustível → transição):

```
para cada can ativo:
    if retângulo(can) intersecta retângulo(player) (área de contato própria, 32×51 centrada):
        can.estado = COLETADO; devolve ao pool (redefinindo posição/estado/referências)
        emit fuel_can_collected(fuel_can_restore_amount)
        # GameplayManager: fuel_system.restaurar(valor)  ← única via de escrita (R4)
```

- **Zero interação com `CollisionSystem`**: sem `collision_occurred`, sem perda de velocidade, sem deriva, sem penalidade, sem cooldown (FR-024/SC-009). A coleta é silenciosa para o pipeline de colisão por construção — o can nunca entra no snapshot de veículos.
- Sobreposição por vários quadros ⇒ uma única coleta (estado `COLETADO` + devolução imediata ao pool no mesmo quadro).
- Contato fora de `PLAYING` não coleta (o update inteiro só roda no ramo — FR-024/AS7).

**Alternativas descartadas**:
- *Detector genérico do `CollisionSystem`* — rejeitado: exigiria classes de colisão para itens e contaminaria o contrato SPEC-005 (cooldown/deriva/penalidade).
- *`Area2D` com `body_entered` do engine* — rejeitado: o projeto usa detecção manual por retângulos em todos os sistemas (consistência + testabilidade headless sem física).

**Referências**: `src/collision/collision_system.gd`, spec FR-024, Clarification "coleta não é colisão".

---

## R9 — Ordem canônica de atualização por quadro (FR-017, casos de borda 4/5, Clarificação de rearme)

**Decisão**: ramo `PLAYING` do `GameplayManager._process` (após física do player, que corre no próprio nó):

1. rolagem da estrada e do fundo (`road.update_scroll_speed`, `background_layer`);
2. decoração → trânsito → colisão NPC×NPC → limites do jogador → colisão jogador×NPC (hierarquia já validada nas SPEC-004–006);
3. **galões**: movimentação → reciclagem na base → geração → coleta/restauração (R7/R8);
4. **combustível**: `fuel_system.update(delta, get_speed())` (consumo após a restauração do quadro);
5. **progressão**: `track_manager.update(delta, get_speed())` e marcadores (rolagem);
6. **transições**: vitória (cruzamento + combustível > 0) → senão, `GAME_OVER` se `combustível == 0 and speed == 0 and não concluída`;
7. flag de bloqueio de aceleração (R5) derivada do valor pós-consumo.

- Esgotamento e cruzamento no mesmo quadro: o consumo roda antes da checagem de vitória ⇒ **precedência do esgotamento** (caso de borda 1).
- Coleta no mesmo quadro do esgotamento: a restauração (passo 3) antecede o consumo (passo 4) ⇒ `min(atual + recuperado, capacidade)` entra na conta do quadro (caso de borda 4).
- Coleta no mesmo quadro da parada que originaria `GAME_OVER`: a transição (passo 6) só ocorre com zero **após** o consumo; se a coleta restaurou, o valor é positivo e não há transição (caso de borda 5). `GAME_OVER` nunca é revertido: uma vez emitido, o ramo PLAYING deixa de rodar.
- A ordem é **uma só** e documentada no contrato `game_state_transitions.md` (FR-017).

**Referências**: `src/game/gameplay_manager.gd:133–186` (hierarquia atual), spec casos de borda 1/4/5, FR-017.

---

## R10 — Reset completo orquestrado (FR-003/FR-035, SC-012)

**Decisão**: `GameplayManager` orquestra um `reset` único na transição **READY → PLAYING** (e no fluxo Reiniciar/Tentar novamente, que passa por READY) — hoje só `fuel_system.reset()` é chamado (`gameplay_manager.gd:199`). Cada sistema ganha um `reset()` próprio e idempotente:

| Sistema | Reset |
|---|---|
| `TrackManager` | percorrida/restante/percentual/concluído/sinais |
| `TrackMarkers` | remove marcadores e recria início/chegada para a nova corrida |
| `FuelSystem` | `definir_capacidade_derivada` + `reset()` (R3) |
| `FuelCanManager` | devolve todos ao pool, zera contadores (`gerados`, `desde_ultima`), limpa pendências |
| `PlayerVehicle`/`VehicleController` | `controller.reset()` (já existe), posição inicial, flag de combustível, sprite selecionado |
| `Road` | `scroll_speed = 0`, `scroll_offset = 0`, tipos de segmento do início |
| `TrafficManager` | pool/ativos/reciclagem/crômetro/pendente/vabilitação |
| `CollisionSystem`/`NpcCollisionSystem` | cooldowns, sobrepostos, drifts, cadeias, janelas |
| `DecorationManager` | elementos e baseline de scroll |
| UI | painéis conforme o novo estado; indicadores zerados |

- **Conexões de sinais são feitas uma única vez no `_ready`** (padrão `setup` idempotente já usado pelo HUD, H4) — o reset nunca reconecta (SC-012: 0 conexões repetidas).
- "Voltar ao menu": mesmos resets do encerramento + esconder mundo; nenhum sistema continua avançando (FR-036) — reforçado por R11 (rolagem zerada na pausa/menu).

**Alternativas descartadas**:
- *Recarregar a cena inteira em cada reinício* — rejeitado: recriaria autoloads/nós desnecessariamente, quebraria os testes de unidade que instanciam sistemas soltos e mudaria o fluxo READY existente; a constituição pede mudanças mínimas.
- *Reset centralizado "por reflection"* — rejeitado: acoplaria o GameplayManager a internals de cada sistema; chamadas explícitas são auditáveis.

**Referências**: `src/game/gameplay_manager.gd:193–227`, `src/player/vehicle_controller.gd:113`, `src/fuel/fuel_system.gd:33`, spec FR-003/FR-035.

---

## R11 — Pausa que congela tudo, incluindo a rolagem (FR-004, SC-012)

**Decisão**: em `_on_state_changed` para `PAUSED`: `road.update_scroll_speed(0.0)`; para `PLAYING` (retomada) o próprio ramo volta a chamar `update_scroll_speed(get_speed())`. Correção necessária: hoje `Road._process` aplica a **última** `scroll_speed` recebida enquanto pausado (o manager para de atualizar, mas não zera) — a estrada continuaria rolando sob pausa (FR-004 exige movimento interrompido). Marcadores e galões herdam o freeze por dependerem de `scroll_speed`; trânsito/decoração/colisões/consumo/progresso já só rodam no ramo PLAYING; a verificação de chegada fica no passo 6 (R9), também só em PLAYING. Retomada: posições idênticas às da pausa, sem deslocamento acumulado (SC-012) — o `delta` da pausa não é aplicado a nada.

**Referências**: `src/road/road.gd:122–128/197`, `src/game/gameplay_manager.gd:225–227`, spec FR-004.

---

## R12 — UIManager: observador puro com comandos por sinal (FR-001/FR-005/FR-034/FR-041)

**Decisão**: `src/ui/ui_manager.gd` (`class_name UIManager extends Control`), montado em um `CanvasLayer` da `gameplay.tscn`:

- **Painéis**: `MenuPanel` (título + seleção de veículo azul/vermelho + "Iniciar"), `PausePanel` (Continuar/Reiniciar/Voltar ao menu), `VictoryPanel` ("Tentar novamente"/"Voltar ao menu"), `GameOverPanel` (idem), `DistanceIndicator` (rótulo + barra). Todos construídos com `Control`/`ColorRect`/`Label` (mesma estética do `FuelHud`; escala inteira, sem AA).
- **Observação**: `setup(track_manager, game_state)` conecta `progress_changed` e `state_changed`; o indicador congela sozinho quando o track para de emitir (pausa); nunca escreve em Track/Fuel/Player.
- **Comandos**: sinais `start_race`, `select_next_vehicle`, `continue_race`, `restart_race`, `go_to_menu` consumidos pelo `GameplayManager`, que chama `GameState`/resets — o `GameState` continua o único dono das transições (FR-001).
- **Entrada**: ações já existentes (`ui_accept`, `ui_cancel`, `ui_up/down/left/right`); em `PAUSED`, `ui_cancel` = Continuar (compatível com o atalho atual de Escape).
- **Seleção de veículo**: `GameplayManager._veiculo_selecionado: String = "azul"` (persiste durante a sessão no menu; padrão azul no boot — AS2), aplicada via `player_vehicle.change_sprite()`; sem alteração de atributos (FR-002/SC-001).
- **Textos**: 100% vindos de `GameConfig.ui_*` (§VI); o formato de distância usa o template `ui_distance_format` com `snprintf`-style (`"Distância: %.1f km / %.1f km"`).

**Alternativas descartadas**:
- *Cenas separadas por estado (PackedScene trocada)* — rejeitado: o projeto é single-scene; trocar cenas quebraria os nós de gameplay observados e os testes headless.
- *UI escrevendo em `GameState` diretamente* — rejeitado: mantém-se o padrão "UI emite → GameplayManager decide → GameState transiciona" (FR-005: interface observadora; FR-001: transições centralizadas).
- *`print`/input cru como está hoje no menu* — rejeitado: a spec exige telas com as opções (SC-017).

**Referências**: `src/ui/fuel_hud.gd` (padrão observador + textos de config), `src/game/gameplay_manager.gd:211–227`, `src/game/game_state.gd`, spec FR-002/FR-034/FR-041.

---

## R13 — Valores-semente de configuração (CALIBRAÇÃO — FR-039, SC-016)

**Decisão**: bloco `## Progressão e Itens (SPEC-008)` em `GameConfig` (**CALIBRAÇÃO**, provisórios):

| Parâmetro | Semente | Nota |
|---|---|---|
| `track_total_distance` | `5.0` km | valor do texto-fonte, provisório |
| `track_units_to_km` | `0.00034722` | derivado de `KMH_TO_SPEED_UNIT` (R1) |
| `fuel_consumption_per_distance` | `40.0` un/km | R3 |
| `fuel_safety_margin` | `60.0` un | R3 |
| `fuel_can_restore_amount` | `25.0` un | global p/ todos os ambientes (Clarificação) |
| `fuel_can_spawn_interval_distance` | `0.35` km | intervalo-base antes da taxa por ambiente |
| `fuel_can_min_spacing` | `120.0` px | entre galões (qualquer eixo) |
| `fuel_can_npc_spacing` | `24.0` px | infla o retângulo na validação contra NPCs |
| `fuel_can_start_offset` | `0.15` km | longe do INÍCIO |
| `fuel_can_finish_offset` | `0.25` km | longe da CHEGADA |
| `fuel_can_max_active` | `3` | teto simultâneo (testável, barato) |
| `fuel_can_min_per_race` / `max_per_race` | `4` / `12` | total por corrida (Clarificação) |
| `fuel_can_spawn_rate` | `{PLAINS:1.4, DESERT:1.0, FOREST:0.7, ICE:0.5}` | ordem por construção |
| `ui_*` (rótulos) | pt-BR | §VI; sem literais na lógica |

**Referências**: bloco SPEC-007 em `src/config/game_config.gd:419–460` (padrão de seção), Clarifications 2026-10-10.
