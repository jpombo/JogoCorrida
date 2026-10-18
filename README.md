# JogoCorrida

Jogo de corrida arcade 2D em pixel art, desenvolvido em **Godot 4.7.2** (GDScript) com arquitetura **spec-driven (SDD)**.

## Prova de Conceito (PoC)

> **Este projeto é uma Prova de Conceito** — não é um jogo de produção.
>
> O objetivo do JogoCorrida é demonstrar, de ponta a ponta, um **pipeline de desenvolvimento orientado por especificação** (spec → plan → tasks → implement) aplicado a um jogo real no Godot: cada funcionalidade nasce de um documento de especificação em pt-BR (`specs/NNN-…/`), vira plano, tarefas e código, com testes automatizados e aceite manual rastreados nos próprios artefatos.
> Por ser uma PoC: o escopo é didático/demonstrativo, o balanceamento é experimental (todo parametrizado para ajuste), assets são placeholders/curados de pixel art e não há planos de publicação. A qualidade de engenharia, porém, é tratada a sério — constituição do projeto, suíte de testes completa e rastreabilidade extrema (cada decisão registrada em `research.md`/`contracts/`).

## Tecnologias e versões

| Item | Versão | Observação |
|---|---|---|
| Godot Engine | **4.7.2** (stable) | Cena principal: `res://src/game/gameplay.tscn` |
| GdUnit4 | **6.2.0** | Único plugin do projeto (`addons/gdUnit4/`), só para testes |
| GDScript | nativo do Godot 4.7 | Sem plugins de terceiros além do GdUnit4 |

Autoloads (apenas 2): `GameConfig` (parâmetros centralizados) e `GameState` (máquina de estados).

## Funcionalidades implementadas

O jogo está completo em 12 especificações (SPEC-001 … SPEC-012):

### SPEC-001: Controle e Movimento do Veículo
- Controles: acelerar (W/↑), frear (S/↓), esquerda (A/←), direita (D/→)
- Aceleração/frenagem progressiva com inércia; movimento lateral independente; movimento diagonal natural
- Limites de estrada com respeito à largura do carro (16px offset)
- Sprite padrão (azul) com fallback para placeholder; variante vermelha disponível

### SPEC-002: Sistema de Estrada e Scrolling
- Pool de segmentos reutilizáveis; scrolling proporcional à velocidade do jogador; loop contínuo sem gaps
- Suporte a transições (expansão 2→4 vias, redução 4→2 vias) com atualização dinâmica de limites
- Sincronização de limites entre Road e VehicleController

### SPEC-003: Sistema de Ambientes e Cenários
- 4 ambientes selecionáveis por configuração (`GameConfig.current_environment_id`): PLAINS, DESERT, FOREST, ICE
- Backgrounds em pixel art 640×480 renderizados em escala nativa (filtro NEAREST)
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

- Spawn por frequência relativa, com limite de veículos, espaçamento longitudinal e pool reutilizável próprio
- Veículos nascem fora da área visível e são reciclados por qualquer borda
- Assets de NPC normalizados (2026-10-10): 17 PNGs com canvas do contrato (32×64; caminhão 32×128) e conteúdo centrado; sorteio de texturas por categoria uniforme
- **Sem colisão com o jogador** neste spec — a colisão é tratada pelo SPEC-005 por hitbox
- Faixas laterais **reservadas por velocidade** no nascimento (rápidas à esquerda, lentas à direita) e densidade mínima de 3 veículos junto ao jogador com teto por dificuldade (máx. 5 visíveis em Gelo)

**Decoração lateral** — biblioteca por ambiente, distribuída nos dois lados da estrada em 3 profundidades, sempre fora da área trafegável:

| Ambiente | Elementos | Percentuais (`weight`, somam 100) |
|---|---|---|
| PLAINS (planice) | 5 | árvore 80, casa 5, feno 7, milho 6, silo 2 |
| DESERT (deserto) | 5 | árvores 36,5 + 36,5, cactus 20, duna 5, casa 2 |
| FOREST (floresta) | 4 | árvores 48 + 48, lago 3, serra 1 |
| ICE (gelo) | 3 | árvore 96, boneco 3, casa 1 |

- `repeatable` é **dado de configuração** (não do nome do arquivo); sorteio ponderado com compensação de viés das regras de repetição
- Troca de ambiente em runtime: alterar `GameConfig.current_environment_id` propaga fundo e decoração automaticamente

### SPEC-005: Sistema de Colisão e Drift
- Detecção por hitbox retangular independente do sprite (hitboxes derivadas do bbox visível e recalibradas em 2026-10-10)
- 3 tipos de colisão (jogador na traseira do NPC; lateral; NPC na traseira do jogador), com cooldown por par
- Perda de velocidade do jogador dentro de intervalo configurável (nunca abaixo de zero); o NPC **nunca perde velocidade**
- Drift do jogador em 3 fases (impacto → drift → recuperação), com resposta lateral reduzida durante o drift
- Ultrapassagem do NPC com **retorno obrigatório à faixa de origem**; bloqueio da aceleração pós-colisão por janela configurável
- Zero regressão sem contato (SPECs 001–004 idênticos quando não há colisão)

### SPEC-006: Sistema de Colisão entre NPCs
- Contato NPC×NPC por áreas físicas por categoria, classificado longitudinal/lateral, com causador/atingido
- Previsão com janela de atividade e reavaliação ao mudar a velocidade do jogador
- Resposta 100% lateral: drift no atingido, causador intacto, **velocidade intocável em nenhuma fase**
- Limites da pista respeitados inclusive na transição 2↔4 vias; cadeia dominó com profundidade máxima e expiração; validação de spawn no `TrafficManager`
- Evento informativo com 7 campos (FR-041)
- **Pendência conhecida**: FR-046 (o espaçamento mínimo cede entre velocidades diferentes na mesma trajetória durante o movimento) — ainda não implementado; causa-raiz documentada pela sonda `test_traffic_corridor_probe.gd`

### SPEC-007: Sistema de Combustível
- Tanque com consumo contínuo (taxa por segundo crescente com a velocidade, modelo linear configurável), independente da taxa de quadros
- Colisão com consequência por ambiente (FOREST/ICE perdem combustível; PLAINS/DESERT não)
- Eventos exatamente 1× por ocorrência (`fuel_depleted`, `fuel_low`) com latch rearmedo só na nova partida
- HUD somente observador (barra + rótulo "BAIXO"); inicialização exclusivamente em READY → PLAYING
- Balanceamento 100% via configuração (`fuel_*` + `collision_fuel_penalty`)

### SPEC-008: Progressão da Pista, Estados, Combustível e Galões
- Corrida com distância total (`track_total_distance`, 5,0 km): bandas INÍCIO/CHEGADA já em READY, indicador de distância com barra de progresso
- Ciclo de vida completo de estados: `MENU → READY → PLAYING ↔ PAUSED → VICTORY/GAME_OVER`, com telas de menu (destaque da opção ativa), pausa, vitória e fim de jogo — textos 100% em `GameConfig.ui_strings`
- Reset idempotente em 3 pontos orquestrando estrada, pista, itens, veículo, trânsito, colisões, decoração e UI
- Combustível dimensionado pela corrida + **galões** com pool, geração por distância com taxa por ambiente e coleta sem efeitos de colisão

### SPEC-009: Dificuldade e Balanceamento
- Três modos de dificuldade aplicados a jogador, trânsito, combustível e galões via `DifficultyManager`:

| Modo | Velocidade | Densidade | Freq. galões | Penalidade colisão | Dist. galões |
|---|---|---|---|---|---|
| Relaxante | 1,0× | 0,70 | 1,50 | 0,50 | 0,80 |
| Normal (padrão) | 3,0× | 1,00 | 1,00 | 1,00 | 1,00 |
| Desafio | 4,0× | 1,20 | 0,65 | 1,50 | 1,20 |

- Seletor de modo na linha "Modo" do menu principal (cicla com `ui_accept`)
- Progressão infinita de ambientes (sequência % 4) com ciclos de vitória e bônus de 0,2% de velocidade por ciclo (`RaceProgression`)
- Telas de fim: vitória com "Continuar próxima fase" + "Voltar ao menu"; fim de jogo só com "Voltar ao menu"
- Guarda de quadro no ESC: pausa/retomada nunca acontecem no mesmo quadro da virada de estado

### SPEC-010: Sistema Básico de Áudio
- `AudioManager` com 3 efeitos MP3 (motor do jogador, motor de caminhão, colisão) e **zero `_process`** próprio
- Pools de vozes pré-criadas (motor: uma por veículo da pista + jogador; colisão: pool com roubo LRU quando exausta)
- Matriz de estados: som ligado em PLAYING, pausado em PAUSED (`stream_paused`), demais estados parados
- Gate do jogador: aceleração só toca som quando acelerando sem frear; retomada sem `play()` duplicado

### SPEC-011: Recordes, Troféus, Pontuação e Obstáculos
- `SaveManager` (JSON `user://progresso.json`, escrita atômica `.tmp`) + `ProgressManager`: recordes por modo, histórico, acumulados, troféus/ciclos e fórmula de pontuação
- Troféus por modo (`assets/trofeus/`) e painel de progresso nos painéis de vitória/fim de jogo
- **Obstáculos** (`src/obstacles/`): pool com spawn por distância, gate de disponibilidade por progresso e detecção AABB
  - **Cascalho**: efeito temporário + reciclagem imediata
  - **Poça de água**: **desvia o jogador de meio carro** pelo lado do impacto (sem reduzir aderência), visível e inerte na pista até sair da tela

### SPEC-012: Menu de Configurações e Menu Principal Dinâmico
- **Preferências** (`src/config/preferences_manager.gd`, `user://preferencias.json` via `SaveManager`): áudio ligado/desligado + resolução 640×480 / 1024×768 (4:3), com validação campo a campo, recuperação segura de arquivo ausente/corrompido e aplicação já no arranque
- **Painel de configurações** no menu principal (linha "Configurações"; **não** acessível pelo menu de pausa), com textos e alternâncias 100% via `GameConfig.ui_strings` e sinais para o orquestrador
- **Demonstração automática no menu principal** (`src/menu/menu_demo.gd`): estrada de 2 vias rolando, fundo + decoração, ciclo contínuo Planície → Deserto → Floresta → Gelo com fade (0,75 s + 0,75 s), 2–4 NPCs em velocidade fixa (ignora dificuldade), silenciosa e 100% isolada do gameplay (zero efeitos em combustível/pontuação/recordes), com pausa ao abrir as configurações e reinício limpo ao voltar ao menu
- Janela de tamanho fixo (`window/size/resizable=false`); em janela embutida do editor a troca de resolução vira no-op silencioso (`Engine.is_embedded_in_editor()`) — a preferência persiste e vale em janela standalone/exportada
- Aceite manual (Testes A–I) concluído em 2026-10-18 (2 rodadas; 2 achados corrigidos: ordem de desenho da Road na demo e o guard de janela embutida)

## Controles

| Ação | Teclas |
|---|---|
| Acelerar | W ou ↑ |
| Frear | S ou ↓ |
| Esquerda | A ou ← |
| Direita | D ou → |
| Confirmar / alternar | Enter (accept) |
| Pausar / voltar | Esc (cancel) |

## Como executar

1. Instale o **Godot 4.7.2** (standard, sem .NET).
2. Abra o projeto em Godot — a cena principal já é `src/game/gameplay.tscn` (`F5`).
3. **Importante**: abra o editor **uma vez por máquina** antes de rodar testes headless, para gerar os arquivos `*.import` dos assets (o git os ignora).

## Estrutura do Projeto

```
JogoCorrida/
├── src/
│   ├── audio/audio_manager.gd      # Áudio centralizado (SPEC-010)
│   ├── config/
│   │   ├── game_config.gd          # Parâmetros centralizados (autoload)
│   │   └── preferences_manager.gd  # Preferências áudio/resolução (SPEC-012)
│   ├── environment/
│   │   ├── background_controller.gd # Renderização e scroll do background
│   │   ├── environment_data.gd      # Dados de um ambiente
│   │   └── environment_manager.gd   # Seleção do ambiente atual
│   ├── game/
│   │   ├── gameplay_manager.gd     # Orquestrador da cena de gameplay
│   │   ├── gameplay.tscn           # Cena principal
│   │   ├── game_state.gd           # Máquina de estados (autoload)
│   │   ├── progress_manager.gd     # Recordes, troféus, pontuação (SPEC-011)
│   │   └── race_progression.gd     # Sequência de ambientes e ciclos (SPEC-009)
│   ├── menu/menu_demo.gd           # Demonstração do menu principal (SPEC-012)
│   ├── obstacles/
│   │   ├── obstacle.gd             # Obstáculo: poça/cascalho (SPEC-011)
│   │   └── obstacle_manager.gd     # Pool, spawn por distância, AABB
│   ├── player/
│   │   ├── player_vehicle.gd       # Veículo do jogador
│   │   └── vehicle_controller.gd   # Input, física, limites
│   ├── road/
│   │   ├── road.gd                 # Pool de segmentos, scrolling, reciclagem
│   │   └── road_segment.gd         # Segmento individual
│   ├── save/save_manager.gd        # Persistência JSON atômica (SPEC-011/012)
│   ├── traffic/
│   │   ├── traffic_data.gd         # Categoria de veículo
│   │   ├── traffic_manager.gd      # Spawn, seleção, pool, reciclagem
│   │   └── traffic_vehicle.gd      # Veículo de trânsito
│   ├── collision/                  # Colisão jogador×NPC e NPC×NPC (SPEC-005/006)
│   ├── decoration/                 # Decoração lateral por ambiente (SPEC-004)
│   ├── difficulty/                 # Modos e fatores (SPEC-009)
│   ├── fuel/fuel_system.gd         # Tanque e eventos (SPEC-007/008/009)
│   ├── items/                      # Galões de combustível (SPEC-008)
│   ├── track/                      # Distância, chegada, marcadores (SPEC-008)
│   └── ui/
│       ├── fuel_hud.gd             # HUD de combustível (SPEC-007)
│       └── ui_manager.gd           # Menu (4 linhas), painéis, demo (SPEC-008…012)
├── assets/                         # Ver "Lista de assets"
├── specs/                          # 12 especificações SDD (001…012)
├── tests/unit/                     # Suíte GdUnit4
├── addons/gdUnit4/                 # Plugin de testes 6.2.0
└── tools/resize_decoration_assets.py  # Validador somente-leitura dos assets
```

## Lista de assets

Todos em pixel art, filtro NEAREST; total de **71 arquivos** (53 em uso + 18 originais preservados):

| Pasta | Arquivos | Uso |
|---|---|---|
| `assets/player/` | 2 PNGs (`azul/`, `vermelho/`) | Sprites do jogador (32×64) |
| `assets/estrada/` | 4 PNGs | Estrada: `estrada_2_vias` (base, 144×192), `estrada_expansao_4_vias`, `estrada_2_vias_expandido`, `estrada_reducao_2_vias` |
| `assets/background/` | 4 PNGs (640×480) | Fundo por ambiente: grama (PLAINS), areia (DESERT), floresta (FOREST), neve (ICE) |
| `assets/npcs/caminhao/` | 1 PNG (32×128) | Caminhão madeireiro |
| `assets/npcs/esporte/` | 3 PNGs (32×64) | Carros esportivos |
| `assets/npcs/passeio/` | 6 PNGs (32×64) | Carros de passeio |
| `assets/npcs/utilitario/` | 7 PNGs (32×64) | Utilitários (inclui o "carro-prata", sorteio raro por design) |
| `assets/decoracao/planice/` | 5 PNGs | Decoração PLAINS (árvore, casa, feno, milho, silo) |
| `assets/decoracao/deserto/` | 5 PNGs | Decoração DESERT (árvores, cactus, duna, casa) |
| `assets/decoracao/floresta/` | 4 PNGs | Decoração FOREST (árvores, lago, serra) |
| `assets/decoracao/gelo/` | 3 PNGs | Decoração ICE (árvore, boneco, casa) |
| `assets/decoracao/gasolina.png` | 1 PNG | Galão de combustível (SPEC-008) |
| `assets/decoracao/_originais/` | 18 PNGs | Originais das decorações (fonte, fora do jogo) |
| `assets/obstaculos/` | 2 PNGs | `poca.png` (desvio lateral) e `cascalho.png` (SPEC-011) |
| `assets/trofeus/` | 3 PNGs | Troféus por modo: relaxante, normal, desafio (SPEC-011) |
| `assets/audio/` | 3 MP3 | `carro.mp3` (jogador), `caminhao.mp3`, `colisao.mp3` (SPEC-010) |

Hitboxes de colisão são configuradas em `GameConfig` (`NPC_HITBOX_SIZES`), derivadas do bbox visível de cada sprite — trocar um asset não exige reescrever lógica (constituição, §Independência de Assets).

## Configuração

- Resolução base: 640×480 (pixel art, `stretch/mode=viewport`); janela 4:3 em 640×480 ou 1024×768 (não redimensionável livremente)
- FPS alvo: 60

Tudo é configurável em `src/config/game_config.gd` (autoload `GameConfig`), com blocos por spec:

- **Trânsito**: `traffic_enabled`, `traffic_max_vehicles`, `traffic_spawn_*`, `traffic_min_spacing`/`_separation`, `traffic_min_visible`, `traffic_max_visible_by_difficulty`, `traffic_frequency_<categoria>`
- **Decoração**: `decoration_enabled`, `decoration_density`, `decoration_spacing_*`, `decoration_depth_*`, `decoration_scale`, `decoration_tree_repeat_limit`
- **Colisão/drift**: `collision_*`, `drift_*`, `npc_overtake_*`, `player_hitbox_size` e `NPC_HITBOX_SIZES`
- **Colisão NPC×NPC**: `npc_collision_*`, `npc_drift_*`, `npc_chain_*`, `npc_spawn_safety_distance`, entre outros
- **Combustível**: `fuel_capacity`, `fuel_consumption_*`, `fuel_low_*`, `collision_fuel_penalty`
- **Progressão/galões**: `track_total_distance`, `fuel_consumption_per_distance`, `fuel_can_*`, `test_track_sequence`
- **Dificuldade (SPEC-009)**: `difficulty_modes` (tabela acima), `difficulty_default_mode`, `difficulty_cycle_bonus_increment`, `environment_sequence`
- **Áudio (SPEC-010)**: `audio_*` (pools, volumes, streams)
- **Pontuação/obstáculos (SPEC-011)**: `score_*`, `obstaculo_*`, `trofeu_assets`, `save_arquivo`, `poca_desvio_lateral`, `cascalho_*`
- **Preferências/demo (SPEC-012)**: `preferencias_arquivo`, `preferencias_padrao_*`, `preferencias_resolucoes`, `demo_duracao_ambiente`, `demo_fade_*`, `demo_npc_max`/`_intervalo`, `demo_spawn_tentativas`, `demo_velocidade`, `demo_ui_scrim_alpha`
- **Bibliotecas**: `TRAFFIC_CATEGORIES` (velocidade, pasta, assets, frequência) e `DECORATION_LIBRARIES` (`asset`, `repeatable`, `weight`)

## Testes

**78 suítes GdUnit4** em `tests/unit/`, **512 casos verdes** (inclui `test_constitution.gd`, regressão dos princípios da constituição):

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
# tudo verde quando o runner sai com exit 101
```

Cobertura por domínio: preferências, configurações e demo do menu (SPEC-012); áudio (SPEC-010); save/progressão/pontuação/obstáculos (SPEC-011); dificuldade/progressão (`difficulty_*`/`cycle_*`, SPEC-009); pista/galões/telas (SPEC-008); combustível (SPEC-007); colisão NPC×NPC (`npc_*`, SPEC-006); colisão do jogador (`collision_*`, SPEC-005); trânsito (incluindo a sonda de corredor `test_traffic_corridor_probe.gd`, só-reporta, evidência da pendência FR-046); decoração; estrada; ambiente; física do jogador; performance; regressão do SPEC-004; e constituição.

Relatórios gerados em `reports/` (ignorados pelo git).

## Fluxo de desenvolvimento (spec-driven)

Comandos definidos em `.opencode/commands/speckit.*.md` (ler o comando antes de executá-lo):

- `/speckit.specify` → criar nova especificação
- `/speckit.clarify` → esclarecer ambiguidades da spec (opcional)
- `/speckit.plan` → criar plano de implementação
- `/speckit.tasks` → gerar tarefas
- `/speckit.implement` → implementar tarefas (TDD RED→GREEN)
- `/speckit.analyze` → verificação somente-leitura de consistência entre artefatos
- `/speckit.converge` → checagem final de lacunas spec ↔ código e consolidação

Cada feature vive em `specs/NNN-nome-curto/` com `spec.md`, `plan.md`, `tasks.md` e (opcionalmente) `research.md`, `data-model.md`, `contracts/` e `quickstart.md`. As regras não negociáveis do projeto estão em `.specify/memory/constitution.md`.

## Estado e pendências

- Branch atual de desenvolvimento: **`dev`** (`main` é a base estável)
- SPEC-001 … SPEC-011: implementadas, com aceite manual concluído e commits na `dev`
- SPEC-012: implementada e aceita (2026-10-18) — pendências de fluxo: converge/commit
- **Pendência técnica conhecida** (SPEC-006): FR-046 — cedência do espaçamento mínimo de trânsito entre velocidades diferentes na mesma trajetória; causa-raiz documentada pela sonda de corredor
- Dívida registrada da SPEC-004: recuo de faixa para faixa alheia e convergência no estreitamento sem rechecagem de ordenação

## Licença

Não definida — repositório privado/didático (PoC).
