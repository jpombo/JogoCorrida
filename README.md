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
│   │   └── traffic_vehicle.gd    # Veículo de trânsito (sem colisão)
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
│   └── 004-traffic-and-decoration/
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
- **Sem colisão**: nenhum objeto do spec tem corpo de física (FR-026, FR-049)
- Cada veículo expõe os 6 atributos de FR-002 — tipo, posição, velocidade, **direção**, faixa e estado — mais a área ocupada, prontos para o SPEC-005 (`get_vehicles_data()`)

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

## Configuração

- Resolução: 640x480 (pixel art)
- FPS alvo: 60
- Asset sprite do carro: 32x64 pixels
- Asset da estrada: 144x192 pixels
- Assets de background: 640x480 pixels (nativos da viewport)
- Ambiente padrão: PLAINS (alterável via `GameConfig.current_environment_id`)

Tudo é configurável em `src/config/game_config.gd` (autoload `GameConfig`):

- **Trânsito**: `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_distance`, `traffic_spawn_interval`, `traffic_min_spacing` e `traffic_frequency_<categoria>`
- **Decoração**: `decoration_enabled`, `decoration_density`, `decoration_spacing_min/max`, `decoration_depth_count/spacing`, `decoration_scale`, `decoration_safety_margin`, `decoration_tree_repeat_limit`
- Bibliotecas: `TRAFFIC_CATEGORIES` (velocidade, pasta, assets, frequência) e `DECORATION_LIBRARIES` (`asset`, `repeatable`, `weight`)
- Agrupamentos somente leitura para o futuro SPEC-008: `traffic_tuning` e `decoration_tuning`

## Testes

13 suítes GdUnit4 em `tests/unit/`, **112 casos verdes** (inclui `test_constitution.gd`, regressão dos princípios da constitution v2.0.0):

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
# tudo verde quando o runner sai com exit 101
```

Relatórios gerados em `reports/` (ignorados pelo git). Abra o editor Godot uma vez por máquina antes do headless para gerar os `*.import` dos assets.

## Comandos

- `/speckit.specify` → Criar nova especificação
- `/speckit.plan` → Criar plano de implementação
- `/speckit.tasks` → Gerar tarefas
- `/speckit.implement` → Implementar tarefas

## Dependências

- Godot Engine 4.7.2
- GdUnit4 6.2.0 (testes unitários)
