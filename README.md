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
│   └── road/
│       ├── road.gd               # Pool de segmentos, scrolling, reciclagem
│       └── road_segment.gd       # Segmento individual da estrada
├── assets/
│   ├── background/               # Backgrounds por ambiente (640x480)
│   ├── estrada/                  # Sprites de estrada (2 vias, expansão, redução)
│   ├── npcs/                     # Sprites de carros NPC
│   └── player/                   # Sprites do jogador (azul, vermelho)
├── specs/                        # Documentação spec-driven
│   ├── 001-vehicle-control-movement/
│   ├── 002-road-scrolling-system/
│   └── 003-environment-scenarios/
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

## Configuração

- Resolução: 640x480 (pixel art)
- FPS alvo: 60
- Asset sprite do carro: 32x64 pixels
- Asset da estrada: 144x192 pixels
- Assets de background: 640x480 pixels (nativos da viewport)
- Ambiente padrão: PLAINS (alterável via `GameConfig.current_environment_id`)

## Comandos

- `/speckit.specify` → Criar nova especificação
- `/speckit.plan` → Criar plano de implementação
- `/speckit.tasks` → Gerar tarefas
- `/speckit.implement` → Implementar tarefas

## Dependências

- Godot Engine 4.x
- GdUnit4 (testes unitários)
