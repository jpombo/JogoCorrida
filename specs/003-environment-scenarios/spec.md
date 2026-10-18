# Feature Specification: Sistema de Ambientes e Cenários

**Feature Branch**: `003-environment-scenarios`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "Implementar o sistema de ambientes visuais do jogo, permitindo que diferentes trechos/níveis de jogo apresentem paisagens distintas. O sistema deverá introduzir quatro ambientes: Planície (dificuldade 1), Deserto (dificuldade 2), Floresta (dificuldade 3) e Gelo (dificuldade 4). Cada ambiente deverá possuir identificação própria, background próprio, nível de dificuldade base, configuração independente e possibilidade de ser selecionado pelo nível/pista. O sistema deverá ser preparado para que futuras especificações possam associar parâmetros de gameplay ao nível de dificuldade."

---

## User Scenarios & Testing

### User Story 1 - Exibir Ambiente Visual com Background (Priority: P1)

O jogador inicia uma pista e visualiza um cenário de fundo (background) que identifica visualmente o ambiente atual. O background deve preencher toda a tela sem espaços vazios, sem bordas perceptíveis e sem cortes visuais. O background deve ser uma textura seamless que pode ser repetida horizontal e verticalmente.

**Por que esta prioridade**: Esta é a base visual do sistema de ambientes. Sem ela, não existe identidade visual de nível e o jogo permanece com apenas a estrada sobre um fundo genérico.

**Teste Independente**: Pode ser testado selecionando cada um dos quatro ambientes e verificando se o background correto é exibido, preenchendo toda a área visível.

**Cenários de Aceitação**:

1. **Dado** que o ambiente PLAINS está selecionado, **Quando** o jogo é iniciado, **Então** o background exibe a textura de grama (Seamless Pixel Art Grass Texture.png) cobrindo toda a tela.
2. **Dado** que o ambiente DESERT está selecionado, **Quando** o jogo é iniciado, **Então** o background exibe a textura de areia (Pixel Art Desert Sand Texture.png) cobrindo toda a tela.
3. **Dado** que o ambiente FOREST está selecionado, **Quando** o jogo é iniciado, **Então** o background exibe a textura de floresta (Pixel Art Forest Floor Texture.png) cobrindo toda a tela.
4. **Dado** que o ambiente ICE está selecionado, **Quando** o jogo é iniciado, **Então** o background exibe a textura de gelo (Pixel Art Snowy Ice Texture.png) cobrindo toda a tela.
5. **Dado** que qualquer ambiente está ativo, **Quando** observo a tela, **Então** não há espaços vazios, bordas perceptíveis ou cortes visuais no background.

---

### User Story 2 - Sincronizar Movimento do Background com a Estrada (Priority: P1)

O background deve acompanhar visualmente o deslocamento da estrada. Quando o jogador acelera, o background deve se movimentar na mesma direção que a estrada, evitando que a estrada pareça estar se movimentando sobre uma imagem estática. A velocidade visual do background deve ser configurável.

**Por que esta prioridade**: Sem sincronização visual, o jogo parece quebrado — a estrada se move mas o fundo fica parado, criando um artefato visual inaceitável.

**Teste Independente**: Pode ser testado acelerando e freando o veículo, verificando que o background se move coerentemente com a estrada.

**Cenários de Aceitação**:

1. **Dado** que o jogador está em movimento, **Quando** a velocidade aumenta, **Então** o background se desloca visualmente na mesma direção que a estrada.
2. **Dado** que o jogador está em movimento, **Quando** a velocidade diminui, **Então** a velocidade visual do background também diminui proporcionalmente.
3. **Dado** que o jogador está parado (velocidade zero), **Quando** observo a tela, **Então** o background permanece estático ou coerente com o estado de parada da estrada.
4. **Dado** que o background está em movimento, **Quando** observo a tela, **Então** a repetição do background é visualmente contínua durante o scrolling.

---

### User Story 3 - Selecionar Ambiente por Configuração (Priority: P2)

O ambiente deve ser selecionável por configuração, sem necessidade de alterar código. A configuração centralizada deve definir qual ambiente (e consequentemente qual background e nível de dificuldade) está ativo para cada pista/nível.

**Por que esta prioridade**: Permite adicionar novos ambientes e associar níveis a ambientes sem modificar a lógica do jogo, seguindo o princípio de design Configuration-Driven.

**Teste Independente**: Pode ser testado alterando a configuração do ambiente e verificando que o jogo carrega o background e a dificuldade correspondentes.

**Cenários de Aceitação**:

1. **Dado** que a configuração define o ambiente como PLAINS, **Quando** o jogo é iniciado, **Então** o ambiente Planície é carregado com dificuldade base 1.
2. **Dado** que a configuração define o ambiente como DESERT, **Quando** o jogo é iniciado, **Então** o ambiente Deserto é carregado com dificuldade base 2.
3. **Dado** que a configuração define o ambiente como FOREST, **Quando** o jogo é iniciado, **Então** o ambiente Floresta é carregado com dificuldade base 3.
4. **Dado** que a configuração define o ambiente como ICE, **Quando** o jogo é iniciado, **Então** o ambiente Gelo é carregado com dificuldade base 4.
5. **Dado** que a configuração de ambiente é alterada, **Quando** o jogo é reiniciado, **Então** o novo ambiente é carregado sem necessidade de modificar código-fonte.

---

### User Story 4 - Manter Funcionalidade da Estrada Sobre Qualquer Ambiente (Priority: P1)

A estrada implementada no SPEC-002 deve continuar funcionando perfeitamente sobre qualquer um dos quatro backgrounds. Todas as funcionalidades existentes (scrolling, transições entre 2 e 4 vias, limites da estrada) devem permanecer inalteradas.

**Por que esta prioridade**: A regressão funcional é inaceitável. Se a estrada quebrar ao trocar de ambiente, o jogo fica injogável.

**Teste Independente**: Pode ser testado executando todas as funcionalidades da estrada (movimento, scrolling, transições de vias) com cada um dos quatro ambientes.

**Cenários de Aceitação**:

1. **Dado** que o ambiente PLAINS está ativo, **Quando** o jogador se move, acelera e freia, **Então** todos os comportamentos da estrada funcionam corretamente.
2. **Dado** que o ambiente DESERT está ativo, **Quando** o jogador se move, acelera e freia, **Então** todos os comportamentos da estrada funcionam corretamente.
3. **Dado** que o ambiente FOREST está ativo, **Quando** o jogador se move, acelera e freia, **Então** todos os comportamentos da estrada funcionam corretamente.
4. **Dado** que o ambiente ICE está ativo, **Quando** o jogador se move, acelera e freia, **Então** todos os comportamentos da estrada funcionam corretamente.
5. **Dado** que qualquer ambiente está ativo, **Quando** a estrada transita de 2 para 4 vias e volta para 2 vias, **Então** todas as transições ocorrem sem interferência do background.

---

### User Story 5 - Fornecer Dificuldade Base para Sistemas Futuros (Priority: P3)

Cada ambiente deve disponibilizar seu nível de dificuldade para que sistemas futuros (como gerenciamento de trânsito, obstáculos, combustível) possam utilizá-lo como parâmetro de configuração.

**Por que esta prioridade**: Prepara o sistema para a evolução futura sem implementar a mecânica de dificuldade agora. É um requisito de arquitetura que permite crescimento sustentável.

**Teste Independente**: Pode ser testado verificando que cada ambiente fornece corretamente seu nível de dificuldade (PLAINS=1, DESERT=2, FOREST=3, ICE=4).

**Cenários de Aceitação**:

1. **Dado** que o ambiente PLAINS está ativo, **Quando** consulto a dificuldade base, **Então** o valor retornado é 1.
2. **Dado** que o ambiente DESERT está ativo, **Quando** consulto a dificuldade base, **Então** o valor retornado é 2.
3. **Dado** que o ambiente FOREST está ativo, **Quando** consulto a dificuldade base, **Então** o valor retornado é 3.
4. **Dado** que o ambiente ICE está ativo, **Quando** consulto a dificuldade base, **Então** o valor retornado é 4.

---

### Edge Cases

- O que acontece se a configuração de ambiente referenciar um asset que não existe? O sistema deve usar fallback para o background de PLAINS e emitir uma mensagem de warning no console. O jogo continua jogável.
- Como o sistema behave se a textura de background não for seamless? O sistema deveWarn mas permitir a exibição (a qualidade visual será comprometida, mas o jogo não deve quebrar).
- O que acontece se a configuração de dificuldade estiver inconsistente (ex: PLAINS com dificuldade 5)? O sistema deve utilizar o valor configurado, cabendo à validação de configuração garantir a consistência.

---

## Requirements

### Functional Requirements

- **FR-001**: O sistema deve suportar quatro ambientes: PLAINS (Planície), DESERT (Deserto), FOREST (Floresta), ICE (Gelo).
- **FR-002**: Cada ambiente deve possuir um identificador único (ID lógico), um nome exibido e um asset de background associado.
- **FR-003**: Cada ambiente deve possuir um nível de dificuldade base (1 para PLAINS, 2 para DESERT, 3 para FOREST, 4 para ICE).
- **FR-004**: O background de cada ambiente deve ser uma textura seamless que pode ser repetida verticalmente para cobrir toda a área visível. A repetição é apenas na direção vertical (scroll para baixo), mesmo eixo da estrada.
- **FR-005**: O background deve preencher a tela sem espaços vazios, bordas perceptíveis ou cortes visuais.
- **FR-006**: O background deve se movimentar visualmente em sincronia com o deslocamento da estrada.
- **FR-007**: A velocidade visual do background deve ser derivada da velocidade do jogador ou do scrolling da estrada, com um multiplicador global configurável (aplicado igualmente a todos os ambientes).
- **FR-008**: Com velocidade zero, o movimento do background deve parar ou permanecer coerente com o estado de parada da estrada.
- **FR-009**: A seleção do ambiente deve ocorrer por configuração centralizada, sem lógica condicional espalhada pelo código. A configuração deve ser implementada como um dicionário/tabela de dados centralizado, acessível por ID lógico (ex: `ENVIRONMENTS["PLAINS"]`).
- **FR-010**: A estrada do SPEC-002 deve permanecer funcionando sobre qualquer background.
- **FR-011**: A ordem de renderização deve ser: Background → Estrada → Veículo do jogador.
- **FR-012**: O sistema deve ser preparado para suportar diferença de velocidade entre estrada e background (parallax), sem exigir implementação complexa nesta versão.
- **FR-013**: O ambiente deve disponibilizar seu nível de dificuldade para sistemas futuros.
- **FR-014**: A alteração de um asset de background não deve exigir alteração da lógica de seleção do ambiente.
- **FR-015**: Os backgrounds devem preservar características de pixel art: sem suavização, sem filtros desnecessários, sem escalas fracionárias.
- **FR-016**: O ambiente deve ser preparado para suportar transições diretas entre ambientes (ex: Planície → Deserto).
- **FR-017**: O sistema deve ser preparado para suportar modificadores próprios por ambiente no futuro.

### Key Entities

- **Ambiente**: Representa o contexto visual e a identidade de uma região da pista. Possui identificação (ID lógico), nome exibido, asset de background e nível de dificuldade base.
- **Background**: Textura seamless associada a um ambiente. Responsável por preencher a área visível do jogo e acompanhar visualmente o deslocamento da estrada.
- **Configuração de Nível**: Associa um ambiente a um nível/pista, definindo qual cenário e dificuldade estão ativos.

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Todos os quatro ambientes podem ser selecionados por configuração e exibem o background correto.
- **SC-002**: O background preenche 100% da área visível da tela em todos os ambientes, sem espaços vazios.
- **SC-003**: A repetição do background é visualmente contínua — não há bordas perceptíveis entre repetições.
- **SC-004**: O background se move visualmente em sincronia com a estrada durante todo o gameplay.
- **SC-005**: Com velocidade zero, o background para de se mover ou permanece coerente com o estado da estrada.
- **SC-006**: Todas as funcionalidades do SPEC-001 e SPEC-002 continuam funcionando com qualquer ambiente ativo (zero regressões).
- **SC-007**: A troca de ambiente ocorre por alteração de configuração, sem necessidade de modificar código-fonte.
- **SC-008**: Cada ambiente fornece corretamente seu nível de dificuldade base (PLAINS=1, DESERT=2, FOREST=3, ICE=4).
- **SC-009**: A alteração de um asset de background não requer alteração da lógica de seleção do ambiente.
- **SC-010**: Os backgrounds preservam características de pixel art durante renderização e repetição.

---

## Clarifications

### Session 2026-09-23

- Q: Como a configuração de ambiente deve ser persistida e acessada pelo sistema? → A: Dicionário/tabela de dados centralizado no código, acessível por ID lógico (ex: `ENVIRONMENTS["PLAINS"]`)
- Q: O background deve se mover apenas na direção vertical ou também horizontalmente? → A: Apenas scroll vertical (para baixo) — mesmo eixo da estrada.
- Q: Existe um requisito de performance para o rendering do background? → A: Sem meta formal — verificar durante implementação que não há queda perceptível de FPS.
- Q: Quando a configuração referencia um asset de background que não existe, qual o comportamento? → A: Usar fallback para o background de PLAINS + mensagem de warning no console.
- Q: O background_multiplier deve ser fixo por ambiente ou global? → A: Um valor global único para todos os ambientes (configurável).

## Assumptions

- Os assets de textura (Seamless Pixel Art Grass Texture.png, Pixel Art Desert Sand Texture.png, Pixel Art Forest Floor Texture.png, Pixel Art Snowy Ice Texture.png) estão disponíveis no projeto ou serão fornecidos.
- A estrada implementada no SPEC-002 já possui um mecanismo de scrolling que pode ser consultado para sincronizar o movimento do background.
- O projeto possui um mecanismo de configuração existente que pode ser utilizado para centralizar as configurações de ambiente.
- O backgroundMultiplier (fator de multiplicação da velocidade do background em relação à estrada) será configurável e terá um valor padrão razoável.
- A ordem de renderização atual do projeto já suporta a camada de background abaixo da estrada.
- O pixel art dos backgrounds será fornecido com dimensões e qualidade adequadas para repetição seamless. **Ajuste (2026-09-23)**: os quatro assets de background foram dimensionados em **640x480** (mesma resolução da viewport) durante a implementação para exibição nítida em escala 1:1, sem escala fracionária.
- O estado inicial padrão do jogo será o ambiente PLAINS.
- A implementação não inclui efeitos climáticos, ciclo dia/noite, efeitos sonoros específicos por ambiente ou transição visual gradual entre ambientes.
