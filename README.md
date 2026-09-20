# JogoCorrida

Jogo de Corrida desenvolvido em Godot 4 com arquitetura spec-driven (SDD).

## Estrutura do Projeto

```
JogoCorrida/
├── src/
│   ├── config/game_config.gd     # Parâmetros centralizados (autoload)
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
│   ├── estrada/                  # Sprites de estrada (2 vias, expansão, redução)
│   ├── npcs/                     # Sprites de carros NPC
│   └── player/                   # Sprites do jogador (azul, vermelho)
├── specs/                        # Documentação spec-driven
│   ├── 001-vehicle-control-movement/
│   └── 002-road-scrolling-system/
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

## Configuração

- Resolução: 640x480 (pixel art)
- FPS alvo: 60
- Asset sprite do carro: 32x64 pixels
- Asset da estrada: 144x192 pixels

## Comandos

- `/speckit.specify` → Criar nova especificação
- `/speckit.plan` → Criar plano de implementação
- `/speckit.tasks` → Gerar tarefas
- `/speckit.implement` → Implementar tarefas

## Dependências

- Godot Engine 4.x
- GdUnit4 (testes unitários)
