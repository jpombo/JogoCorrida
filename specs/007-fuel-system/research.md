# Research — Sistema de Combustível (SPEC-007)

**Data**: 2026-10-09 | **Base**: `spec.md` (34 FR, 17 SC) + Constituição v2.0.0 + código das SPEC-001–006

Cada decisão abaixo resolve uma questão aberta do plano com **raciocínio, alternativas descartadas e referências verificáveis**. Itens marcados como **CALIBRAÇÃO** têm valores-semente propositalmente provisórios — o ajuste fino é tarefa explícita do plano (FR-028, teste T27).

---

## R1 — Modelo de consumo por quadro (FR-004/FR-005/FR-006, SC-003)

**Decisão**: consumo calculado a cada quadro dentro da chamada `FuelSystem.update(delta, velocidade)`:

```
normalizada   = clamp(velocidade / GameConfig.max_speed, 0.0, 1.0)   # sem divisão por zero: max_speed > 0 é invariante do projeto (SPEC-001)
taxa          = idle_consumo (se velocidade <= 0.0)
                senão clamp(consumo_min + normalizada * consumo_fator, consumo_min, consumo_max)
combustivel  -= taxa * delta
combustivel   = clamp(combustivel, 0.0, capacidade)
```

- **`consumo_fator = consumo_max − consumo_min`** como derivado (evita 4º parâmetro acoplado: mover `min` mantém `max` como teto absoluto).
- Velocidade exatamente zero → `fuel_consumption_idle` (FR-007: "MAY ser zero" — semente **0.0**, ver R9). O descontinuidade 0→`min` no arranque é permitida pela lista de bordas da spec e documentada (caso de borda 6).
- **Independência de taxa de quadros** (SC-003): a função é linear em `delta` — `taxa * delta` some-mesmo para sequências de `delta` distintas com mesma soma total (erro apenas de ponto flutuante; teste com tolerância 1%).

**Alternativas descartadas**:
- *Consumo fixo por quadro (constante × 1/60)* — rejeitado: viola FR-005/SC-003 em 30/60 FPS.
- *Consumo por distância percorrida* — rejeitado: o modelo causal da spec é tempo × velocidade (FR-004), e distância exigiria integrar pista/scroll (fora do escopo do módulo).
- *Normalizar por `speed_changed` acumulado* — rejeitado: ver R6.

**Referências**: `src/player/vehicle_controller.gd` (`speed`), `src/player/player_vehicle.gd:70` (`get_speed()`), `src/config/game_config.gd:~20` (`max_speed = 100.0`).

---

## R2 — Penalidade de colisão: consumir o evento da SPEC-005, sem deduplicação própria (FR-012/FR-013/FR-015, SC-010/SC-011)

**Decisão**: `GameplayManager` conecta `collision_system.collision_occurred` → `FuelSystem.on_player_collision(data)`. O sistema **não re-verifica** cooldown/sobreposição:

- `CollisionSystem` já emite **no máximo 1 evento por colisão válida** (guarda `_cooldowns` + `_sobrepostos` em `collision_system.gd:62`) e só emite colisões envolvendo o player — 1 sinal ⇒ 1 desconto (FR-013 satisfeito *por construção*).
- Colisões NPC×NPC (SPEC-006) são filtradas **antes** aqui: nem chegam ao sinal (SC-011).
- A penalidade usa apenas `GameConfig.current_environment_id` (o payload `CollisionData` é ignorado além de sinalizar "houve colisão").

**Alternativas descartadas**:
- *FuelSystem detectar sobreposição própria* — rejeitado: duplicaria a SPEC-005, com risco de divergência (2 fontes de verdade).
- *Deduplicar de novo no FuelSystem (cooldown próprio)* — rejeitado: estado duplicado e desnecessário; a spec diz "respeitar o cooldown **existente**" (FR-013).
- *Ler `data.intensidade_drift` para escalar o desconto* — rejeitado: a spec fixa penalidade **constante por ambiente** (FR-014); ver R10.

**Referências**: `src/collision/collision_system.gd:13` (sinal), `specs/005-collision-drift-system/contracts/collision_event.md`, `specs/006-npc-collision-system/src` (NPC×NPC não emite).

---

## R3 — Mapa de penalidades como `@export Dictionary` nomeado `collision_fuel_penalty` (FR-014/FR-026/FR-027, SC-016)

**Decisão**: no bloco `GameConfig`:

```gdscript
## Penalidade de colisão por ambiente (SPEC-007) — 0.0 onde não há risco
@export var collision_fuel_penalty: Dictionary = {
    "PLAINS": 0.0,
    "DESERT": 0.0,
    "FOREST": 3.0,   # CALIBRAÇÃO (T27 — teste de gameplay)
    "ICE":    3.0,
}
```

- **Formato escolhido segue o próprio texto conceitual da spec** (`§9.6`/`§13`): `collision_fuel_penalty: {PLAINS: …}` — a spec diz explicitamente "a estrutura acima é conceitual; usar o formato do projeto", e o nome `collision_fuel_penalty` é literalmente o citado pela constituição §IV.
- **`@export`** (não `var` puro como `ENVIRONMENTS`/`NPC_HITBOX_SIZES`): o mapa é **balance** — FR-028 exige ajuste por testes de gameplay, e `@export` Dictionary aparece no inspector do autoload, permitindo iteração sem recompilar lógica. `ENVIRONMENTS` é `var` comum porque contém texturas/ninhos (`game_config.gd:51`).
- **Chave ausente → `0.0`**: ambiente futuro sem cadastro cai no comportamento "sem risco" (igual a PLAINS) em vez de erro — falha silenciosa *para baixo*, compatível com a progressão de dificuldade.
- Valores `FOREST = ICE = 3.0` (3% do tanque de 100 por colisão): **semente** derivada do exemplo ilustrativo da spec §9.7 (penalidade 2 com capacidade 100); calibração explícita na US5.

**Alternativas descartadas**:
- *4 escalars `@export fuel_penalty_forest` etc.* — rejeitado: quebra o formato-mapa da spec e da constituição.
- *`var` puro minúsculo* — rejeitado: some do inspector e atrapalha a calibração exigida por FR-028.
- *Cópia local do mapa dentro do FuelSystem* — rejeitado: FR-026 exige centralização.

---

## R4 — Momento e vida útil: reset só em READY → PLAYING; consumo só no ramo PLAYING (FR-009/FR-022, premissas 11–13)

**Decisão**:
- `GameplayManager._on_state_changed(old, new)` chama `fuel_system.reset()` **apenas quando `old == READY && new == PLAYING`** — ou seja, na transição disparada por `game_state.begin_playing()`.
- `fuel_system.update(delta, get_speed())` é chamado **dentro do ramo `PLAYING`** de `_process` (após `collision_system.update(...)` para que a penalidade do quadro e o consumo do quadro sejam aplicados na mesma iteração, em qualquer ordem — o clamp final dá o mesmo resultado).
- Pausa (`PAUSED → PLAYING` via `resume_game()`) **não** re-inicializa o tanque; MENU/READY **não** consomem nada (consumo é tempo de corrida ativa — premissa 11).

**Alternativas descartadas**:
- *`FuelSystem._process` próprio* — rejeitado: ou rodaria em estados errados (não-frenagem: MENU/READY/PAUSED) ou exigiria que o FuelSystem lesse `GameState` global — acoplamento à máquina de estados que a constituição §III quer evitar ("nenhum objeto decide estado global").
- *Reset em **toda** entrada em PLAYING* — rejeitado: reabriria o tanque ao retomar do pause (bug garantido; `resume_game()` → `game_state.gd:34`).
- *Reset via `game_state.state_changed` com sinal genérico* sem velho/novo — rejeitado: sem o estado anterior não dá para distinguir READY→PLAYING de PAUSED→PLAYING (verificado: o sinal carrega `old_state`/`new_state`).

**Referências**: `src/game/game_state.gd:24,27,34`, `src/game/gameplay_manager.gd` (`_on_state_changed`, ramo `PLAYING` do `_process`).

---

## R5 — Eventos: `fuel_changed` por variação real; `fuel_low` e `fuel_depleted` como latches rearmedes no `reset()` (FR-017/FR-018/FR-019/FR-020, SC-013)

**Decisão**:
- `fuel_changed(atual: float, capacidade: float)` — emitido **somente quando** `atual != anterior` (float-compare com `is_equal_approx` para evitar ruído de ponto flutuante); a cada consumo/penalidade, **não** a cada quadro parado.
- `fuel_low` — **latch**: a condição `atual/capacidade <= limite` é avaliada após cada atualização válida; quando cruza (ou já inicia) o limiar, emite **1×** e arma `_baixo_sinalizado`; rearma **somente** no `reset()`.
- `fuel_depleted` — **latch** idêntico (`_esgotado_emitido`): emitido 1× na primeira vez que `atual` atinge 0 (qualquer que seja a origem — consumo lento ou desconto de colisão); rearma no `reset()`. Pós-esgotamento: `update()` vira no-op de consumo (FR-010).
- **Condição inicial baixa** (caso de borda 15): o `reset()` define os valores e **emite `fuel_low` na hora se `inicial/capacidade <= limite`**, de modo que a assinatura "desde o início" é satisfeita sem depender do primeiro `update()` — mas nunca duplica, pois aram o latch no próprio `reset()`.
- `fuel_low` **mantém-se verdadeiro enquanto a condição persistir**: o HUD (R7) traduz "sinalização persistente + cor" de FR-025 observando o estado (Fase B liga o sinal ao estado do HUD; o rótulo fica visível enquanto `atual <= limite`, não apenas no instante do disparo — ver contrato do HUD).

**Alternativas descartadas**:
- *Debounce temporal (re-emitir após N segundos)* — rejeitado: introduce latência arbitrária, quebra SC-013 ("não mais que 1× por esgotamento") e é difícil de testar determinísticamente.
- *Emitir `fuel_low` a cada quadro abaixo do limiar* — rejeitado: spam de sinal; a spec pede "sinalizado **desde** o início" (estado), não repetição.
- *Um único sinal `fuel_state_changed(estado: enum)`* — rejeitado: a spec nomeia os 3 sinais (FR-017/018/019) e contratos já existem no texto.

---

## R6 — Velocidade consumida "pull", não por sinal `speed_changed` (FR-004, SC-003)

**Decisão**: o `GameplayManager` passa `player_vehicle.get_speed()` como argumento de `update(delta, velocidade)`. O FuelSystem **não** assina `speed_changed`.

- O consumo é uma **integral no tempo** (`taxa(t) * delta`); o tick precisa do valor atual *e* do `delta` — sinais de mudança são eventos discretos e não carregam o intervalo decorrido.
- Evita que o FuelSystem dependa de `VehicleController` (mantém o acoplamento no manager, que já orquestra tudo — mesma decisão da SPEC-006 sobre os guards de atualização).
- `max_speed` vem de `GameConfig` (fonte única; o teto é configuração §IV, não "unidade de velocidade de runtime").

**Alternativas descartadas**: assinar `speed_changed` (sem `delta`, dependência extra); ler `VehicleController.speed` diretamente dentro do FuelSystem (acoplamento direto a um sistema de outra spec).

---

## R7 — HUD: `CanvasLayer` + `ColorRect` planos + `Label`, texto via config (FR-024/FR-025, Clarification 2026-10-09, §VI, §Independência de Assets)

**Decisão**: composição na `gameplay.tscn`:

```
FuelHudLayer (CanvasLayer, layer alto)
└── FuelHudRoot (Control, layout retângulo total, mouse_filter=IGNORE)
    ├── Fundo (ColorRect, canto superior esquerdo, pixel-alinhado)
    ├── Preenchimento (ColorRect — largura = round(proporção * largura_trilho))
    └── Label "BAIXO" (texto: GameConfig.fuel_low_label; visível ⇔ estado baixo)
```

- `fuel_hud.gd` (`Node`/`Control`): conecta-se a `fuel_changed` (atualiza largura) e ao estado baixo (troca cor do `Preenchimento` + visibilidade do `Label`) — **somente leitura**, nunca chama métodos de escrita do FuelSystem (§Sistema de Combustível: "UI SHOULD observar…").
- Retângulos planos + escala inteira: pixel-art do jogo, sem suavização, sem tema — o projeto **não tem nenhuma UI hoje**, então não há tema/estilo a herdar.
- Texto "BAIXO" **não** é literal no script: `GameConfig.fuel_low_label` (§VI — único texto de usuário novo, já externalizado).

**Alternativas descartadas**:
- `ProgressBar` nativo — rejeitado: depende de Theme/StyleBox (cantos arredondados, suavização) e não há tema no projeto; maior superfície para teste visual.
- Sprite de barra (asset PNG) — rejeitado: §Independência de Assets (trocar arte não pode tocar lógica) e a spec diz "indicador mínimo".
- Sons/animações — rejeitados pela Clarification 2026-10-09 (escopo do indicador).
- HUD no próprio `player_vehicle.gd` — rejeitado: mistura simulação com apresentação (§III).

---

## R8 — Estratégia de teste determinística (SC-002/SC-003/SC-004, §Testes)

**Decisão**: as 6 suítes instanciam `FuelSystem.new()` diretamente (padrão das suítes 005/006, ex.: `collision_event_test.gd`) e **chamam `update(delta, velocidade)` sintético** — sem rodar o loop de frames:

- `SC-002`/`SC-004` (determinismo): mesma entrada ⇒ mesmo saída — trivial com chamadas diretas.
- `SC-003` (taxas de atualização): `sum(delta_i * taxa_i)` é idêntico para qualquer particionamento do mesmo tempo — teste com `10×0.1s` vs `100×0.01s` e tolerância 1%.
- Penalidades: `on_player_collision()` chamado com `GameConfig.current_environment_id` temporariamente trocado (restaurado em `after_test` — padrão de mutação de config já usado nas suítes existentes).
- HUD (`fuel_hud_test.gd`): instancia `fuel_hud.gd` headless, alimenta com um `FuelSystem` real e afirma proporção de largura + visibilidade do rótulo; **não** depende de renderização (apenas propriedades de nó).
- Suite `fuel_config_test.gd` (T27): muta cada parâmetro novo, chama `update()`, afirma o efeito — prova FR-026 sem tocar na lógica.

**Alternativas descartada**: testes via cena/integração rodando frames reais — rejeitado: lentos e não-determinísticos; a suíte atual já valida a integração por convenção de wiring (mesmo padrão das specs anteriores).

---

## R9 — Bloco de configuração e valores-semente (FR-026/FR-027/FR-028, SC-016, §IV)

**Decisão**: bloco `## Combustível (SPEC-007)` em `GameConfig`:

| Parâmetro | Semente (CALIBRAÇÃO) | Papel |
|---|---|---|
| `fuel_capacity` | `100.0` | Capacidade máxima; divisor do limiar e da proporção do HUD |
| `fuel_initial_amount` | `-1.0` (sentinela: `-1 ⇒ capacidade`) | Permite tanque inicial < capacidade sem 2º valor fixo |
| `fuel_consumption_idle` | `0.0` | Repouso não consome (FR-007 "MAY ser zero"; sem "motor ligado em marcha lenta" — semântica limpa) |
| `fuel_consumption_min` | `0.6` /s | Consumo na mínima velocidade > 0 |
| `fuel_consumption_max` | `2.0` /s | Teto absoluto (≈50 s de corrida em velocidade máxima) |
| `fuel_consumption_speed_factor` | `1.4` /s | Inclinatura da curva (`min + norm*factor ≤ max`) |
| `fuel_low_threshold` | `0.2` | Fração da capacidade que dispara `fuel_low` |
| `collision_fuel_penalty` | ver R3 | 0/0/3/3 por ambiente |
| `fuel_low_label` | `"BAIXO"` | Texto do HUD (§VI) |

- **Validação**: `fuel_capacity > 0` é guard de divisão (caso de borda 3: capacidade 0 → sem eventos, sem NaN — checado no guard de `low`).
- Sementes **exploratórias** (ritmo arcade: dezenas de segundos, não minutos); os 27 testes fixam os *invariantes* (monotonicidade, teto, clamps), e o **T27 + testes manuais de gameplay** ajustam números (FR-028).

**Alternativas descartada**: valores hardcoded em `fuel_system.gd` (FR-026/§IV); parser/JSON externo (fora do padrão — todo balance do projeto vive em `GameConfig`).

---

## R10 — Divergência conhecida: contrato 005 diz "proporcional à intensidade", spec 007 fixa penalidade constante

**Decisão**: **a spec 007 prevalece** — penalidade **constante por ambiente** (FR-014), sem uso de `intensidade_drift`/`velocidade_impacto`.

- O contrato 005 (`specs/005-collision-drift-system/contracts/collision_event.md`, seção "Consumidores futuros") é uma *sugestão de uso futuro*, não um requisito vinculante da SPEC-005 — a SPEC-005 não especifica combustível (o texto do combustível nasceu na 007).
- A intensidade continua **disponível no payload** para balanceamento futuro (ex.: especiais da US5/008) sem custo de mudança.
- Registrado aqui para `/speckit.analyze` não sinalizar contradição de contrato: consumidor 007 ignora campos que não precisa.

---

## R11 — Costura com a SPEC-008 (Game Over / vitória): fronteira do escopo

**Decisão**: o FuelSystem **só expõe estado + eventos**; nenhum gating de gameplay por esgotamento nesta spec.

- Durante a SPEC-007, com combustível em 0 o **veículo continua dirigindo normalmente** (FR-030: sem efeitos em velocidade/física) — comportamento observável previsto e documentado no quickstart.
- A SPEC-008 consumirá `fuel_depleted` (+ condição de posição/vitória) para transições de estado; `reset()` dela (ou extensão futura de R4) não está em escopo.
- Também fica para lá: efeitos de colisão em *estados* (§Estado de Jogo), sons, sprites de barra especiais.

---

## R12 — Wiring consolidado (pontos de toque exatos)

| Ponto | Mudança | Arquivo |
|---|---|---|
| Instância | `const FuelSystem = preload(...)` + `fuel_system = FuelSystem.new()` | `gameplay_manager.gd` `_ready` |
| Reset | `if old == READY and new == PLAYING: fuel_system.reset()` | `_on_state_changed` |
| Tick | `fuel_system.update(_delta, player_vehicle.get_speed())` após `collision_system.update(...)` | `_process` ramo `PLAYING` |
| Penalidade | `collision_system.collision_occurred.connect(fuel_system.on_player_collision)` | `_ready` |
| HUD | `fuel_hud.setup(fuel_system)` (conexões dos 2 sinais) — **ou** conexões feitas no manager; decisão: `fuel_hud.gd` recebe o sistema via método `setup()` e se conecta sozinho (UI encapsulada) | `_ready` + cena |
| Cena | `CanvasLayer` + `Control` + 2×`ColorRect` + `Label` | `gameplay.tscn` |
| Config | bloco `## Combustível (SPEC-007)` | `game_config.gd` |

Nenhum outro arquivo é editado (SC-017).
