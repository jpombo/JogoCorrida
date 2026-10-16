# JogoCorrida

Jogo de Corrida desenvolvido em Godot 4 com arquitetura spec-driven (SDD).

## Estrutura do Projeto

```
JogoCorrida/
├── src/
│   ├── config/game_config.gd     # Parâmetros centralizados (autoload)
│   ├── environment/
│   │   ├── background_controller.gd # Renderização e scroll do background
│   │   ├── environment_data.gd      # Dados de um ambiente (id, nome, asset, dificuldade)
│   │   └── environment_manager.gd   # Seleção e consulta do ambiente atual
│   ├── game/
│   │   ├── gameplay_manager.gd   # Gerenciador de cena de gameplay
│   │   ├── gameplay.tscn         # Cena principal
│   │   ├── game_state.gd         # Máquina de estados
│   │   └── race_progression.gd   # Sequência de ambientes, ciclos e bônus (SPEC-009)
│   ├── player/
│   │   ├── player_vehicle.gd     # Veículo do jogador (sprite, collision, posição)
│   │   └── vehicle_controller.gd # Lógica de controle (input, física)
│   ├── road/
│   │   ├── road.gd               # Pool de segmentos, scrolling, reciclagem
│   │   └── road_segment.gd       # Segmento individual da estrada
│   ├── traffic/
│   │   ├── traffic_data.gd       # Categoria de veículo (velocidade, assets, frequência)
│   │   ├── traffic_manager.gd    # Spawn, seleção, pool e reciclagem de veículos
│   │   └── traffic_vehicle.gd    # Veículo de trânsito (área ocupada, ultrapassagem lateral)
│   ├── collision/
│   │   ├── collision_data.gd     # Evento de colisão (par, tipo 1-1/1-2/1-3, velocidade, intensidade, drift)
│   │   ├── collision_system.gd   # Detecção, classificação e consequências (cooldown, perda, drift, ultrapassagem)
│   │   ├── drift_state.gd        # Fases do drift do jogador (impacto, drift, recuperação)
│   │   ├── npc_overtake_state.gd # Deslocamento lateral do NPC com retorno à faixa de origem (FR-021)
│   │   ├── npc_collision_data.gd # Evento NPC×NPC com os 7 campos (SPEC-006, FR-041)
│   │   ├── npc_collision_system.gd # Contato, previsão, cadeia, cooldown e validação de spawn (SPEC-006)
│   │   ├── npc_chain_state.gd    # Cadeia dominó: id, profundidade, timeout, processados (SPEC-006)
│   │   └── npc_drift_state.gd    # Fases do drift do NPC, sem mudança de velocidade (SPEC-006)
│   ├── decoration/
│   │   ├── decoration_data.gd    # Elemento da biblioteca (repeatable, weight)
│   │   ├── decoration_manager.gd # Biblioteca por ambiente, profundidades, sorteio
│   │   └── decoration_element.gd # Sprite decorativo (sem colisão)
│   ├── difficulty/
│   │   └── difficulty_manager.gd # Modo vigente, 5 fatores por modo e fator de ciclo (SPEC-009)
│   ├── fuel/
│   │   └── fuel_system.gd        # Tanque: consumo, penalidade por ambiente e eventos (SPEC-007/008/009)
│   ├── items/
│   │   ├── fuel_can.gd           # Galão de combustível (SPEC-008)
│   │   └── fuel_can_manager.gd   # Geração, pool e reciclagem de galões (SPEC-008/009)
│   ├── track/
│   │   ├── track_manager.gd      # Distância da corrida, chegada e progresso (SPEC-008)
│   │   └── track_markers.gd      # Bandas INÍCIO/CHEGADA e indicador de distância (SPEC-008)
│   └── ui/
│       ├── fuel_hud.gd           # Barra + rótulo de combustível, somente observador (SPEC-007)
│       └── ui_manager.gd         # Menu (3 linhas), pausa, vitória, fim de jogo (SPEC-008/009)
├── assets/
│   ├── background/               # Backgrounds por ambiente (640x480)
│   ├── decoracao/                # Decoração por ambiente (planice, deserto, floresta, gelo)
│   ├── estrada/                  # Sprites de estrada (2 vias, expansão, redução)
│   ├── npcs/                     # Veículos em 4 pastas: caminhao, esporte, passeio, utilitario
│   └── player/                   # Sprites do jogador (azul, vermelho)
├── specs/                        # Documentação spec-driven
│   ├── 001-vehicle-control-movement/
│   ├── 002-road-scrolling-system/
│   ├── 003-environment-scenarios/
│   ├── 004-traffic-and-decoration/
│   ├── 005-collision-drift-system/
│   ├── 006-npc-collision-system/
│   ├── 007-fuel-system/
│   ├── 008-track-progression-fuel-cans/
│   └── 009-difficulty-balancing/
└── tests/unit/                   # Testes unitários (GdUnit4)
```

## Funcionalidades Implementadas

### SPEC-001: Controle e Movimento do Veículo
- Controles: acelerar (W/↑), frear (S/↓), esquerda (A/←), direita (D/→)
- Aceleração/frenagem progressiva com inércia
- Movimento lateral independente
- Movimento diagonal natural
- Limites de estrada com respeito à largura do carro (16px offset)
- Sprite padrão (azul.png) com fallback para placeholder

### SPEC-002: Sistema de Estrada e Scrolling
- Pool de segmentos reutilizáveis
- Scrolling proporcional à velocidade do jogador
- Loop contínuo sem gaps
- Suporte a transições (expansão 2→4 vias, redução 4→2 vias)
- Atualização dinâmica de limites durante transições
- Sincronização de limites entre Road e VehicleController

### SPEC-003: Sistema de Ambientes e Cenários
- 4 ambientes selecionáveis por configuração (`GameConfig.current_environment_id`): PLAINS, DESERT, FOREST, ICE
- Backgrounds em pixel art 640x480 renderizados em escala nativa (nítidos, filtro NEAREST)
- Scroll do background sincronizado com a estrada (multiplicador configurável — parallax)
- Fallback para PLAINS + warning quando o asset de background não existe
- Dificuldade base por ambiente (PLAINS=1, DESERT=2, FOREST=3, ICE=4)

### SPEC-004: Sistema de Trânsito e Decoração dos Ambientes

**Trânsito** — 4 categorias, cada uma com pasta e velocidade próprias (o jogador anda a 125 km/h):

| Categoria | Velocidade | Pasta |
|---|---|---|
| Caminhão | 90 km/h | `assets/npcs/caminhao/` |
| Esporte | 120 km/h | `assets/npcs/esporte/` |
| Passeio | 100 km/h | `assets/npcs/passeio/` |
| Utilitário | 90 km/h | `assets/npcs/utilitario/` |

- Spawn por frequência relativa (`traffic_frequency_<categoria>`), com limite de veículos, espaçamento longitudinal e pool reutilizável próprio
- Veículos nascem fora da área visível e são reciclados por qualquer borda
- **Assets de NPC normalizados (2026-10-10)**: os 17 PNGs mantêm o canvas do contrato (32×64; caminhão 32×128) com o conteúdo centrado e margens — o espaçamento derivado do tamanho não muda; o sorteio de texturas por categoria é uniforme (sonda de 4000 nascimentos: Carro-prata ~1/7 dos utilitários)
- **Sem colisão com o jogador**: nenhum objeto do spec tem corpo de física (FR-026, FR-049) — a colisão é tratada pelo SPEC-005 por hitbox
- Cada veículo expõe os 6 atributos de FR-002 — tipo, posição, velocidade, **direção**, faixa e estado — mais a área ocupada (`get_vehicles_data()`)
- Faixas laterais **reservadas por velocidade** no nascimento (rápidas à esquerda, lentas à direita), com o espaçamento do limitador derivado das meias-alturas e o comboio considerando apenas o líder do mesmo corredor (ajustes 1, 2 e 5 — FR-019/FR-065, SC-029/SC-030). **Dívida conhecida** (registrada na SPEC-006): o recuo de faixa do nascimento e a convergência ao estreitar a pista ainda podem dividir o corredor entre velocidades distintas
- Densidade mínima de 3 veículos junto ao jogador com reposição imediata por quadro e teto por dificuldade (máx. 5 visíveis em Gelo) (ajuste 3 — FR-063/FR-064, SC-028)

**Decoração lateral** — biblioteca por ambiente, distribuída nos dois lados da estrada em 3 profundidades, sempre fora da área trafegável:

| Ambiente | Elementos | Percentuais (`weight`, somam 100) |
|---|---|---|
| PLAINS (planice) | 5 | árvore 80, casa 5, feno 7, milho 6, silo 2 |
| DESERT (deserto) | 5 | árvores 36,5 + 36,5, cactus 20, duna 5, casa 2 |
| FOREST (floresta) | 4 | árvores 48 + 48, lago 3, serra 1 |
| ICE (gelo) | 3 | árvore 96, boneco 3, casa 1 |

- `repeatable` é **dado de configuração** (não do nome do arquivo): os 6 assets `arvore` podem repetir até 10 vezes seguidas por lado; os demais nunca duas seguidas
- O sorteio é ponderado pelo percentual declarado, com compensação interna do viés das regras de repetição (em Gelo a árvore se aproxima do teto de ~90,9% imposto pelo limite de 10)
- Deslocamento derivado da velocidade da estrada com multiplicador próprio (`decoration_speed_multiplier`), reciclagem por pool próprio e repositicionamento contínuo nas transições 2↔4 vias
- **Troca de ambiente em runtime**: alterar `GameConfig.current_environment_id` propaga automaticamente fundo e biblioteca de decoração, sem alterar código (FR-031)

### SPEC-005: Sistema de Colisão e Drift

- **Detecção por hitbox retangular** independente do sprite (hitbox do jogador e tamanhos por categoria de NPC configuráveis, derivados do conteúdo visível dos sprites e recalibrados em 2026-10-10)
- **3 tipos de colisão** (FR-002): jogador atinge a traseira do NPC; colisão lateral; NPC atinge a traseira do jogador — cada um com suas consequências, precedidos de cooldown por par
- **Perda de velocidade do jogador** dentro de intervalo configurável, nunca abaixo de zero (SC-003); o NPC **nunca perde velocidade** em nenhuma colisão (FR-017, Out of Scope)
- **Drift do jogador** em 3 fases (impacto → drift → recuperação): direção decidida pelo lado relativo com margem neutra determinística, força/duração configuráveis, resposta lateral reduzida a 40% durante o drift e recuperação gradual a 100% (SC-004)
- **Ultrapassagem do NPC** (colisão 1-3): deslocamento lateral temporário para o lado oposto ao drift do jogador, clampado nos limites da estrada por altura, com **retorno obrigatório à faixa de origem** ao fim da ida — sem deslocamento permanente, que fazia o limitador de trânsito acoplar velocidades de categorias distintas (ajuste 6 — FR-019/FR-021, SC-014)
- **Bloqueio da aceleração pós-colisão**: janela configurável em que acelerar não aumenta a velocidade (frenagem continua válida) (ajuste 4 — FR-036, SC-013)
- **Zero regressão sem contato**: sem colisão, todos os SPECs 001–004 comportam-se identicamente (FR-034, SC-010)
- Evento de colisão completo (par, tipo, velocidade de impacto, intensidade, direção do drift) para consumo externo (FR-029/FR-030)

### SPEC-006: Sistema de Colisão entre NPCs

- **Contato NPC×NPC** por áreas físicas por categoria (independentes dos sprites), classificado como longitudinal ou lateral, com intensidade pela velocidade relativa e identificação de causador/atingido (FR-010–FR-013)
- **Previsão com janela de atividade**: par só é considerado potencial se o encontro ocorrer com os dois ainda ativos; par de mesma velocidade ou em trajetórias distintas nunca gera previsão (FR-001–FR-006), com reavaliação ao mudar a velocidade do jogador (FR-032–FR-035)
- **Resposta 100% lateral**: drift no atingido (novo impacto substitui o drift em curso), causador intacto e **velocidade intocável em nenhuma fase** — nem temporariamente (FR-014–FR-017)
- **Limites da pista**: inversão do drift junto à borda, transferência do deslocamento ao causador quando sem espaço, e nenhum veículo sai da área trafegável, inclusive durante a transição 2↔4 vias (FR-018–FR-020, US4)
- **Cadeia dominó controlada**: profundidade máxima, expiração por tempo, zero loops, cooldown isolado por par (FR-024–FR-027)
- **Validação de spawn**: outra posição → outra faixa → adiamento para o quadro seguinte, sem perder o nascimento (FR-028–FR-031, integrado ao `TrafficManager`)
- **Evento informativo** com 7 campos para observadores futuros; nada mais é alterado (FR-041)
- **Clarify 2026-10-09 (trânsito real — FR-046, ainda não implementado)**: o espaçamento mínimo do SPEC-004 cede, durante o movimento, entre velocidades diferentes na mesma trajetória até o contato (é o que torna a US1 alcançável naturalmente); no nascimento e entre pares de mesma velocidade o espaçamento permanece. A causa dos relatos DESERT/FOREST foi reproduzida pela sonda `test_traffic_corridor_probe.gd` (só-reporta) e a dívida de nascimento/convergência da SPEC-004 está registrada na spec.

### SPEC-007: Sistema de Combustível

- **Tanque com consumo contínuo** durante a partida: taxa por segundo que cresce com a velocidade (modelo linear configurável com piso, teto e fator de velocidade) e usa o consumo em repouso no zero de velocidade — independente da taxa de quadros (FR-004–FR-010)
- **Colisão com consequência por ambiente**: PLAINS/DESERT sem perda adicional; FOREST/ICE com perda fixa idêntica entre os dois e entre 2% e 10% da capacidade, acumulativa por evento e sem retroatividade (FR-011–FR-017)
- **Eventos exatamente 1× por ocorrência**: `fuel_depleted` na primeira atingida de zero (qualquer origem, nunca valor negativo) e `fuel_low` na travessia do limiar, ambos com latch rearmedo só na nova partida (FR-018–FR-024)
- **HUD somente observador**: barra em retângulos planos (escala inteira) com proporção sempre igual ao tanque, cor trocada e rótulo estático **"BAIXO"** (texto vindo de `GameConfig.fuel_low_label`) enquanto durar a condição — a UI nunca modifica o combustível (FR-025, Clarificação B)
- **Inicialização exclusivamente em READY → PLAYING**: pausar e retomar não recarrega o tanque (FR-002/FR-003)
- **Balanceamento 100% via configuração** (`fuel_*` + `collision_fuel_penalty`), sem nenhum número fixo na lógica e sem tocar em física, estados ou colisão (FR-026–FR-030); sem Game Over nesta spec (fronteira para a SPEC-008)

### SPEC-008: Progressão da Pista, Estados, Combustível e Galões

- **Corrida com distância total** (`track_total_distance`, 5,0 km por padrão): banda `INÍCIO`/`CHEGADA` criada já na entrada em `READY` e indicador `Distância: 0,0 km / 5,0 km` com barra de progresso (`TrackManager`/`TrackMarkers`)
- **Ciclo de vida completo de estados**: `MENU` → `READY` → `PLAYING` ↔ `PAUSED` → `VICTORY`/`GAME_OVER`, com telas de menu (destaque da opção ativa), pausa, vitória e fim de jogo — textos 100% externalizados em `GameConfig.ui_strings`
- **Reset idempotente em 3 pontos** (preparação menu→READY, virada READY→PLAYING e reinício imediato) orquestrando estrada, pista, itens, veículo, trânsito, colisões, decoração e UI; nada avança em segundo plano no menu
- **Combustível dimensionado pela corrida**: capacidade derivada de `fuel_consumption_per_distance`/`fuel_safety_margin` (corrida de referência com sobra de 15%–35%) + **galões** com pool e reciclagem, geração por distância com taxa por ambiente (planície > deserto > floresta > gelo), piso/teto de 4–12 por corrida e coleta sem efeitos de colisão
- Aceite manual (quickstart passos 1–12 + calibração) concluído em **2026-10-16 sem problemas e sem ajuste de valores**

### SPEC-009: Dificuldade e Balanceamento

- **Três modos de dificuldade** (`GameConfig.difficulty_modes`), aplicados a jogador, trânsito, combustível e galões por injeção do `DifficultyManager` (fallback 1,0 sem injeção — regressão zero nos testes legados):

| Modo | Velocidade | Densidade | Freq. galões | Penalidade colisão | Dist. galões |
|---|---|---|---|---|---|
| Relaxante | 1,0× | 0,70 | 1,50 | 0,50 | 0,80 |
| Normal (padrão) | 3,0× | 1,00 | 1,00 | 1,00 | 1,00 |
| Desafio | 4,0× | 1,20 | 0,65 | 1,50 | 1,20 |

- **Seletor de modo na 3ª linha do menu** ("Modo: Relaxante/Normal/Desafio", cicla com `ui_accept` — placeholder da SPEC-013)
- **Progressão infinita de ambientes** (`environment_sequence` % 4: planície → deserto → floresta → gelo → …) com ciclos de vitória e bônus de **0,2% de velocidade por ciclo** (`RaceProgression`)
- **Telas de fim da SPEC-009** (FR-020/FR-021, substituem o "Tentar novamente" da SPEC-008): vitória com "Continuar próxima fase" + "Voltar ao menu"; fim de jogo só com "Voltar ao menu"; derrota zera o ciclo atual
- **Guarda de quadro no ESC**: pausa/retomada nunca acontecem no mesmo quadro da virada de estado — o painel de pausa (com "Voltar ao menu") é sempre desenhado (`tests/unit/pause_esc_test.gd`)
- Aceite manual (quickstart §3.1–§3.5) concluído em **2026-10-16 sem problemas; calibração §5 não acionada**

## Configuração

- Resolução: 640x480 (pixel art)
- FPS alvo: 60
- Asset sprite do carro: 32x64 pixels
- Asset da estrada: 144x192 pixels
- Assets de background: 640x480 pixels (nativos da viewport)
- Ambiente padrão: PLAINS (alterável via `GameConfig.current_environment_id`)

Tudo é configurável em `src/config/game_config.gd` (autoload `GameConfig`):

- **Trânsito**: `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_distance`/`_variance`, `traffic_spawn_interval`/`_filling`, `traffic_min_spacing`, `traffic_min_separation`, `traffic_min_visible`, `traffic_max_visible_by_difficulty`, `traffic_spawn_fill_distance` e `traffic_frequency_<categoria>`
- **Decoração**: `decoration_enabled`, `decoration_density`, `decoration_spacing_min/max`, `decoration_depth_count/spacing`, `decoration_scale`, `decoration_safety_margin`, `decoration_tree_repeat_limit`
- **Colisão e drift do jogador**: `collision_speed_loss_min/max`, `drift_force_min/max`, `drift_duration_min/max`, `drift_control_factor`, `drift_recovery_rate`, `collision_cooldown_time`, `collision_neutral_margin`, `collision_intensity_divisor`, `npc_overtake_magnitude`/`_duration`/`_return_duration`, `collision_accel_lockout_time`, `player_hitbox_size` e `NPC_HITBOX_SIZES` (hitboxes derivadas do bbox visível: jogador 22×44, passeio/utilitário 22×38, esporte 22×46, caminhão 30×64)
- **Colisão entre NPCs (SPEC-006)**: `npc_collision_cooldown`, `npc_drift_force_min/max`, `npc_drift_duration_min/max`, `npc_drift_recovery_rate`, `npc_relative_position_threshold`, `npc_border_margin`, `npc_max_chain_depth`, `npc_chain_timeout`, `npc_displacement_limit`, `npc_spawn_safety_distance`, `npc_collision_prediction_horizon`, `npc_min_relative_speed`, `npc_active_area_margin`, `npc_reevaluation_interval` e `npc_player_speed_change_threshold`
- **Combustível (SPEC-007)**: `fuel_capacity`, `fuel_initial_amount`, `fuel_consumption_idle`, `fuel_consumption_min`/`_max`/`_speed_factor`, `fuel_low_threshold`, `fuel_low_label` e `collision_fuel_penalty` (penalidade por ambiente)
- **Progressão e galões (SPEC-008)**: `track_total_distance`, `track_units_to_km`, `fuel_consumption_per_distance`, `fuel_safety_margin`, `fuel_can_restore_amount`, `fuel_can_spawn_interval_distance`, `fuel_can_min_spacing`, `fuel_can_npc_spacing`, `fuel_can_start_offset`, `fuel_can_finish_offset`, `fuel_can_max_active`, `fuel_can_min_per_race`/`_max_per_race`, `fuel_can_spawn_rate` (por ambiente), `test_track_sequence` e os rótulos do dicionário `ui_strings`
- **Dificuldade (SPEC-009)**: `difficulty_modes` (os 5 fatores por modo — tabela acima), `difficulty_default_mode`, `difficulty_cycle_bonus_increment` (0,002 = 0,2% por ciclo) e `environment_sequence`
- Bibliotecas: `TRAFFIC_CATEGORIES` (velocidade, pasta, assets, frequência) e `DECORATION_LIBRARIES` (`asset`, `repeatable`, `weight`)
- Agrupamentos somente leituras expostos por specs anteriores: `traffic_tuning` e `decoration_tuning`

## Testes

63 suítes GdUnit4 em `tests/unit/`, **388 casos verdes** (inclui `test_constitution.gd`, regressão dos princípios da constitution):

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
# tudo verde quando o runner sai com exit 101
```

Cobertura principal: 12 suítes de dificuldade/progressão (`difficulty_*`/`cycle_*`, SPEC-009) e `pause_esc_test.gd` (guarda de quadro do ESC); 9 de progressão/galões/telas (`track_*`, `fuel_can_*`, `ui_screens`, `race_reset`, `game_config_008`, SPEC-008); 6 de combustível (`fuel_*`, SPEC-007); 9 de colisão NPC×NPC (`npc_*`, SPEC-006); 8 de colisão do jogador (`collision_*`, SPEC-005); trânsito (incluindo a sonda de corredor `test_traffic_corridor_probe.gd`, **só-reporta** — evidências A/B/D da pendência FR-046 — e a regressão de textura de NPCs); decoração; estrada; ambiente; física do jogador; performance; regressão do SPEC-004; e constituição.

Relatórios gerados em `reports/` (ignorados pelo git). Abra o editor Godot uma vez por máquina antes do headless para gerar os `*.import` dos assets.

## Comandos

Fluxo padrão (definidos em `.opencode/commands/speckit.*.md` — ler o comando antes de executá-lo):

- `/speckit.specify` → Criar nova especificação
- `/speckit.clarify` → Esclarecer ambiguidades da spec (opcional)
- `/speckit.plan` → Criar plano de implementação
- `/speckit.tasks` → Gerar tarefas
- `/speckit.implement` → Implementar tarefas
- `/speckit.analyze` → Verificação somente-leitura de consistência entre artefatos
- `/speckit.converge` → Consolidação final da feature

## Dependências

- Godot Engine 4.7.2
- GdUnit4 6.2.0 (testes unitários)
