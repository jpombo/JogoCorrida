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
│   │   └── game_state.gd         # Máquina de estados
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
│   │   └── npc_overtake_state.gd # Deslocamento lateral do NPC com retorno à faixa de origem (FR-021)
│   └── decoration/
│       ├── decoration_data.gd    # Elemento da biblioteca (repeatable, weight)
│       ├── decoration_manager.gd # Biblioteca por ambiente, profundidades, sorteio
│       └── decoration_element.gd # Sprite decorativo (sem colisão)
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
│   └── 005-collision-drift-system/
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
- **Sem colisão com o jogador**: nenhum objeto do spec tem corpo de física (FR-026, FR-049) — a colisão é tratada pelo SPEC-005 por hitbox
- Cada veículo expõe os 6 atributos de FR-002 — tipo, posição, velocidade, **direção**, faixa e estado — mais a área ocupada (`get_vehicles_data()`)
- Faixas laterais **reservadas por velocidade** (rápidas à esquerda, lentas à direita): velocidades distintas nunca compartilham corredor, o espaçamento do limitador é derivado das meias-alturas e o comboio considera apenas o líder do mesmo corredor (ajustes 1, 2 e 5 — FR-019/FR-065, SC-029/SC-030)
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

- **Detecção por hitbox retangular** independente do sprite (hitbox do jogador e tamanhos por categoria de NPC configuráveis)
- **3 tipos de colisão** (FR-002): jogador atinge a traseira do NPC; colisão lateral; NPC atinge a traseira do jogador — cada um com suas consequências, precedidos de cooldown por par
- **Perda de velocidade do jogador** dentro de intervalo configurável, nunca abaixo de zero (SC-003); o NPC **nunca perde velocidade** em nenhuma colisão (FR-017, Out of Scope)
- **Drift do jogador** em 3 fases (impacto → drift → recuperação): direção decidida pelo lado relativo com margem neutra determinística, força/duração configuráveis, resposta lateral reduzida a 40% durante o drift e recuperação gradual a 100% (SC-004)
- **Ultrapassagem do NPC** (colisão 1-3): deslocamento lateral temporário para o lado oposto ao drift do jogador, clampado nos limites da estrada por altura, com **retorno obrigatório à faixa de origem** ao fim da ida — sem deslocamento permanente, que fazia o limitador de trânsito acoplar velocidades de categorias distintas (ajuste 6 — FR-019/FR-021, SC-014)
- **Bloqueio da aceleração pós-colisão**: janela configurável em que acelerar não aumenta a velocidade (frenagem continua válida) (ajuste 4 — FR-036, SC-013)
- **Zero regressão sem contato**: sem colisão, todos os SPECs 001–004 comportam-se identicamente (FR-034, SC-010)
- Evento de colisão completo (par, tipo, velocidade de impacto, intensidade, direção do drift) para consumo externo (FR-029/FR-030)

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
- **Colisão e drift**: `collision_speed_loss_min/max`, `drift_force_min/max`, `drift_duration_min/max`, `drift_control_factor`, `drift_recovery_rate`, `collision_cooldown_time`, `collision_neutral_margin`, `collision_intensity_divisor`, `npc_overtake_magnitude`/`_duration`/`_return_duration`, `collision_accel_lockout_time`, `player_hitbox_size` e `NPC_HITBOX_SIZES`
- Bibliotecas: `TRAFFIC_CATEGORIES` (velocidade, pasta, assets, frequência) e `DECORATION_LIBRARIES` (`asset`, `repeatable`, `weight`)
- Agrupamentos somente leitura para o futuro SPEC-008: `traffic_tuning` e `decoration_tuning`

## Testes

24 suítes GdUnit4 em `tests/unit/`, **160 casos verdes** (inclui `test_constitution.gd`, regressão dos princípios da constitution v2.0.0):

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
# tudo verde quando o runner sai com exit 101
```

Cobertura principal: 8 suítes de colisão (`collision_*_test.gd`, SPEC-005), 7 de trânsito (`test_traffic_*`, `test_memory_stability`, `test_no_collision`), 3 de decoração, mais estrada, ambiente, física do jogador, performance, regressão do SPEC-004 e constituição.

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
