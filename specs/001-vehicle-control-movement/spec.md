# Feature Specification: Vehicle Control and Movement

**Feature Branch**: `001-vehicle-control-movement`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "SPEC-001 — Controle e Movimento do Veículo do Jogador"

## User Scenarios & Testing

### User Story 1 - Controle Básico do Veículo (Priority: P1)

O jogador deve ser capaz de iniciar uma sessão de jogo e controlar o veículo usando quatro controles básicos: acelerar, frear, mover para esquerda e mover para direita.

**Why this priority**: Este é o núcleo jogável do projeto - sem controle do veículo não há jogo. Todo o restante do gameplay depende desta base.

**Independent Test**: Pode ser totalmente testado iniciando o jogo e verificando que o veículo responde aos quatro controles independentemente e em combinação.

**Acceptance Scenarios**:

1. **Given** o jogador inicia uma sessão, **When** a cena de gameplay carrega, **Then** o veículo aparece na região inferior da estrada usando o sprite azul
2. **Given** o veículo está parado, **When** o jogador mantém `accelerate`, **Then** a velocidade aumenta progressivamente e a posição vertical avança
3. **Given** o veículo está em movimento, **When** o jogador solta `accelerate`, **Then** o veículo desacelera gradualmente devido à inércia
4. **Given** o veículo está em movimento, **When** o jogador mantém `brake`, **Then** a velocidade diminui progressivamente e o veículo retorna para a parte inferior da tela
5. **Given** o veículo está na estrada, **When** `move_left` está ativo, **Then** o veículo move-se para a esquerda dentro dos limites
6. **Given** o veículo está na estrada, **When** `move_right` está ativo, **Then** o veículo move-se para a direita dentro dos limites

---

## Clarifications

### Session 2026-09-18

- Q: Quando o jogador pressiona acelerar e frear ao mesmo tempo? → A: Frenagem tem prioridade (a velocidade diminui)
- Q: O jogador poderá personalizar o mapeamento de controles (teclas) durante o jogo? → A: Não, mapeamento fixo (WASD/setas)
- Q: O jogo deve iniciar automaticamente em PLAYING ou exibir um MENU primeiro? → A: MENU primeiro (MENU→READY→PLAYING)
- Q: O que acontece se os assets de sprite não forem encontrados no disco? → A: Log de erro + placeholder visual (quadrado colorido)
- Q: Qual é o framerate alvo para o gameplay? → A: 60 FPS (padrão arcade)
- Q: Como a câmera deve se comportar em relação ao veículo do jogador? → A: Veículo fixo, estrada rola verticalmente


### User Story 2 - Movimento Vertical Baseado na Velocidade (Priority: P1)

A posição vertical do veículo deve representar visualmente sua velocidade atual, criando a sensação de progressão na pista.

**Why this priority**: A percepção visual de velocidade é essencial para a experiência de jogo arcade top-down. O jogador deve "sentir" a velocidade pela posição do carro na tela.

**Independent Test**: Pode ser testado verificando se a posição Y do veículo corresponde à velocidade atual conforme a faixa vertical configurável.

**Acceptance Scenarios**:

1. **Given** velocidade = 0%, **Then** posição vertical ≈ 85% da área jogável (posição de inércia)
2. **Given** velocidade = 100% (max_speed), **Then** posição vertical ≈ 45% da área jogável (posição de velocidade máxima)
3. **Given** velocidade entre 0% e 100%, **Then** posição vertical interpola suavemente entre os limites
4. **Given** veículo atinge max_speed, **Then** posição vertical não ultrapassa vertical_position_min
5. **Given** veículo para completamente, **Then** posição vertical não ultrapassa vertical_position_max

---

### User Story 3 - Movimento Diagonal Natural (Priority: P1)

Quando houver movimento vertical (aceleração/frenagem) e horizontal simultâneos, o veículo deve percorrer trajetórias diagonais naturais.

**Why this priority**: O movimento diagonal emerge da combinação dos eixos independentes e é essencial para desviar de tráfego futuro mantendo velocidade.

**Independent Test**: Pode ser testado combinando aceleração/frenagem com movimento lateral e verificando trajetória diagonal.

**Acceptance Scenarios**:

1. **Given** acelerando + `move_left`, **Then** veículo desloca-se diagonalmente para cima/esquerda
2. **Given** acelerando + `move_right`, **Then** veículo desloca-se diagonalmente para cima/direita
3. **Given** freando + `move_left`, **Then** veículo desloca-se diagonalmente para baixo/esquerda
4. **Given** freando + `move_right`, **Then** veículo desloca-se diagonalmente para baixo/direita
5. **Given** `move_left` e `move_right` simultâneos, **Then** componente lateral resulta em zero (cancelamento)

---

### User Story 4 - Limites da Estrada e Restrição de Movimento (Priority: P1)

O veículo nunca deve sair da área válida da estrada, com limites horizontais e verticais respeitados.

**Why this priority**: Garante integridade do gameplay - o jogador não pode "trapacear" saindo da pista, e o sistema de colisão futuro depende de limites bem definidos.

**Independent Test**: Pode ser testado tentando mover o veículo além dos limites e verificando que ele permanece dentro.

**Acceptance Scenarios**:

1. **Given** veículo no limite esquerdo, **When** `move_left` continua ativo, **Then** veículo não ultrapassa road_left_boundary
2. **Given** veículo no limite direito, **When** `move_right` continua ativo, **Then** veículo não ultrapassa road_right_boundary
3. **Given** qualquer situação, **Then** posição Y sempre entre vertical_position_min e vertical_position_max
4. **Given** limite atingido, **Then** não ocorre teleportação nem comportamento errático

---

### User Story 5 - Sprite e Configuração Visual (Priority: P2)

O veículo deve utilizar assets reais do projeto (azul.png como padrão) com possibilidade de troca para vermelho.png sem alterar código de controle.

**Why this priority**: Valida a independência entre lógica de gameplay e assets visuais, conforme princípio da constituição.

**Independent Test**: Pode ser testado trocando o recurso visual e verificando que movimento/física permanecem idênticos.

**Acceptance Scenarios**:

1. **Given** sessão iniciada, **Then** veículo utiliza assets/player/azul/azul.png
2. **Given** recurso visual alterado para vermelho.png, **Then** controle e física permanecem inalterados
3. **Given** qualquer movimento, **Then** sprite preserva orientação top-down sem rotação dinâmica

---

### Edge Cases

- O que acontece quando o jogador pressiona acelerar e frear simultaneamente? Resultado esperado: frear tem prioridade (speed diminui)
- Como o sistema lida com valores de velocidade negativos? (Clamped em zero)
- O que ocorre se max_speed for alterado durante o jogo? (Sistema deve respeitar novo valor imediatamente)
- Como a normalização do vetor diagonal afeta velocidades muito altas? (Velocidade total não deve exceder soma dos componentes)
- O que acontece se os assets de sprite não forem encontrados? (Log de erro + placeholder visual quadrado colorido)

## Requirements

### Functional Requirements

- **FR-001**: O sistema DEVE suportar quatro ações lógicas de entrada: accelerate, brake, move_left, move_right
- **FR-002**: O mapeamento DEVE ser fixo: W/↑ → accelerate, S/↓ → brake, A/← → move_left, D/→ → move_right (sem personalização pelo jogador)
- **FR-003**: O sistema de gameplay NÃO DEVE depender diretamente de teclas físicas (usar sistema de Input da engine)
- **FR-004**: O veículo DEVE ter aceleração progressiva quando accelerate mantido pressionado
- **FR-005**: O veículo DEVE ter frenagem progressiva quando brake mantido pressionado
- **FR-005A**: Quando accelerate e brake forem pressionados simultaneamente, a frenagem DEVE prevalecer e a velocidade DEVE diminuir
- **FR-006**: O veículo DEVE ter desaceleração natural (inércia) quando nem accelerate nem brake pressionados
- **FR-007**: A velocidade NÃO DEVE ultrapassar max_speed configurável
- **FR-008**: A velocidade NÃO DEVE ficar abaixo de zero
- **FR-009**: A posição vertical DEVE ser função da velocidade atual (maior velocidade = mais à frente na pista)
- **FR-010**: A posição vertical DEVE respeitar vertical_position_min (velocidade máxima) e vertical_position_max (parado/inércia)
- **FR-011**: O movimento lateral DEVE ser independente da velocidade vertical
- **FR-012**: O movimento lateral DEVE ter aceleração e desaceleração lateral próprias para suavidade
- **FR-013**: A combinação de movimento vertical e horizontal DEVE produzir trajetórias diagonais naturalmente
- **FR-014**: O vetor de movimento diagonal NÃO DEVE causar aumento artificial de velocidade (normalização quando necessário)
- **FR-015**: O veículo NÃO DEVE ultrapassar road_left_boundary nem road_right_boundary
- **FR-016**: Ao atingir limite horizontal, movimento lateral DEVE ser restringido sem teleportação
- **FR-017**: O veículo DEVE utilizar assets/player/azul/azul.png como padrão
- **FR-018**: O sistema DEVE permitir trocar sprite para assets/player/vermelho/vermelho.png sem alterar código de controle
- **FR-019**: O sprite NÃO DEVE ter rotação visual dinâmica nesta especificação
- **FR-020**: A arquitetura DEVE separar: PlayerVehicle (representação, sprite, collision, estado), VehicleController (entrada, cálculos), Road (representação, limites, scrolling futuro)
- **FR-021**: Os seguintes parâmetros DEVEM ser configuráveis centralizadamente: max_speed, acceleration, brake_force, natural_deceleration, lateral_speed, lateral_acceleration, lateral_deceleration, initial_vertical_position, vertical_position_min, vertical_position_max, road_left_boundary, road_right_boundary
- **FR-022**: Valores iniciais de prototipação DEVEM ser: max_speed=100, acceleration=40, brake_force=70, natural_deceleration=15, lateral_speed=100, lateral_acceleration=300, lateral_deceleration=400, initial_vertical_position=95%, vertical_position_min=60%, vertical_position_max=95%
- **FR-023**: Fluxo de estados inicial: MENU → READY → PLAYING. Estado inicial efetivo para gameplay: PLAYING, Speed = 0, Vertical Position = initial_vertical_position, Horizontal Position = centro da faixa, Vehicle = azul.png
- **FR-024**: A estrada DEVE ter área de rodagem, limite esquerdo, limite direito, direção visual de progressão
- **FR-025**: A estrada DEVE estar preparada para scrolling/progressão contínua futura (tilemap, segmentos, repetição de textura)
- **FR-026**: A câmera DEVE usar visão top-down 2D sem perspectiva 3D
- **FR-027**: O veículo DEVE permanecer fixo na tela (região inferior/intermediária) enquanto a estrada rola verticalmente conforme a velocidade

### Key Entities

- **PlayerVehicle**: Representa o veículo do jogador - possui sprite, collision shape, estado físico (velocidade, posição), integra VehicleController
- **VehicleController**: Gerencia lógica de controle - lê inputs, calcula aceleração/frenagem/desaceleração/movimento lateral/vertical
- **Road**: Representa a estrada - área válida, limites laterais (left/right boundary), preparação para sistema de progressão
- **GameState**: Estado global do jogo - mínimo: MENU, READY, PLAYING, PAUSED, VICTORY, GAME_OVER (conforme constituição)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Jogador consegue iniciar sessão e ver veículo na posição inicial (< 2 segundos após carregamento)
- **SC-002**: Veículo atinge max_speed em tempo consistente com parâmetro acceleration (ex: ~2.5s com acceleration=40, max_speed=100)
- **SC-003**: Veículo para completamente partindo de max_speed em tempo consistente com natural_deceleration (ex: ~6.7s com natural_deceleration=15)
- **SC-004**: Veículo para completamente partindo de max_speed com brake em tempo consistente com brake_force (ex: ~1.4s com brake_force=70)
- **SC-005**: Movimento lateral percorre toda largura da estrada em tempo consistente com lateral_speed
- **SC-006**: Posição vertical corresponde à velocidade com margem de erro < 5% da faixa vertical
- **SC-007**: Veículo nunca sai dos limites horizontais da estrada em 100% dos testes de boundary
- **SC-008**: Combinação accelerate+move_left produz trajetória diagonal para cima/esquerda sem aumento artificial de velocidade
- **SC-009**: Troca de sprite (azul ↔ vermelho) não altera comportamento de movimento/física
- **SC-010**: 100% dos critérios de aceitação (CA-001 a CA-020) passam na validação manual
- **SC-011**: Todos os testes automatizados listados (test_*) passam quando suportados pela engine
- **SC-012**: Zero erros no console durante sessão de gameplay de 5 minutos
- **SC-013**: Jogo mantém framerate estável de 60 FPS em hardware de referência (sem stuttering perceptível)

## Assumptions

- Engine suporta sistema de Input com mapeamento de ações lógicas (não hardcoded keys)
- Engine suporta configuração centralizada de parâmetros (ex: recursos, autoload, config files)
- Engine é 2D com sistema de coordenadas onde Y aumenta para baixo (padrão top-down)
- Assets de sprite existem em assets/player/azul/azul.png e assets/player/vermelho/vermelho.png
- Sprites já possuem orientação top-down correta (não requerem rotação em código)
- Sistema de colisão da engine suporta boundary/area checking para limites de estrada
- Engine suporta testes automatizados para lógica determinística (cálculos de posição/velocidade)
- Framerate alvo: 60 FPS (base de tempo para cálculos de física)
- Desenvolvimento segue fase incremental (esta SPEC = Fase 1: Core Movement)
- Próxima SPEC (002) implementará scrolling contínuo da estrada
- Não há necessidade de menus, UI de HUD, ou sistema de pausa nesta SPEC (exceto fluxo MENU→READY→PLAYING)
- Balanceamento final dos valores será feito em iterações posteriores