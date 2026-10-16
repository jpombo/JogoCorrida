# Feature Specification: Sistema de Dificuldade e Balanceamento

**Feature Branch**: `009-difficulty-balancing`

**Created**: 2026-10-12

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-009 — Sistema de Dificuldade e Balanceamento" (três modos de jogo — Relaxante 1,0×, Normal 2,0× e Desafio 3,0× *(valores originais, alterados pelo adendo de 2026-10-14 abaixo)* — aplicando multiplicador de velocidade ao jogador e a todos os NPCs, ajustando densidade de trânsito, frequência de galões, penalidades de combustível por colisão e distância mínima entre gerações de galões, combinados de forma independente com os quatro ambientes existentes, com integração para a seleção do menu da SPEC-013 e testes de balanceamento e regressão — reutilizando, sem duplicar, os sistemas das SPEC-001 a SPEC-008). Adendo do usuário (2026-10-12): jogo projetado como **infinito** — sequência de ambientes planície → deserto → floresta → gelo → planície…; tela de vitória com "Continuar próxima fase" ou "Voltar ao menu"; tela de Fim de Jogo com "Voltar ao menu"; e bônus de velocidade de **0,002 (0,2%)** por ciclo completo de 4 vitórias, tornando o trânsito mais rápido e o desvio mais difícil. **Adendo do usuário (2026-10-14)**: os multiplicadores de velocidade são **Relaxante 1,0×, Normal 3,0× e Desafio 4,0× (quádruplo da base)** — Normal passa a valer o que era do Desafio e o Desafio ganha um patamar novo; os demais fatores por modo (densidade, galões, penalidade, distância) permanecem como estavam.

## Clarifications

### Session 2026-10-14

- Q: Quais multiplicadores de velocidade valem para cada modo de dificuldade, considerando que o comportamento do Desafio agradou mais que o do Normal? → A: Relaxante 1,0×, **Normal 3,0×** (o que era do Desafio) e **Desafio 4,0×** (quádruplo da base); densidade, frequência de galões, penalidade de colisão e distância entre galões mantêm os valores atuais de cada modo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Escolher o modo e correr na velocidade do modo (Priority: P1)

Antes de iniciar, o modo de dificuldade está definido (seleção do jogador ou Normal como padrão). Ao correr em **Relaxante**, o jogador e todos os NPCs mantêm exatamente as velocidades atuais do jogo. Em **Normal**, tudo corre o triplo; em **Desafio**, o quádruplo — mantendo as diferenças relativas entre os veículos (o esportivo continua mais rápido que o passeio, que continua mais rápido que o caminhão). Aceleração, frenagem, direção, as regras de combustível e as regras de colisão continuam funcionando como hoje; apenas a escala de velocidade muda. Reiniciar a corrida não acumula velocidade, e os temporizadores do jogo (contagem de largada, transições de estado) continuam no tempo normal — só os veículos correm mais rápido.

**Why this priority**: É o coração da SPEC-009: o multiplicador de velocidade único e consistente aplicado a jogador e NPCs. É um MVP autossuficiente — com ele, o jogo já oferece três experiências de velocidade reais e jogáveis; os demais ajustes de balanceamento (densidade, galões, penalidades) dependem deste eixo para fazer sentido.

**Independent Test**: Em cada modo, medir a velocidade máxima do jogador e a de cada tipo de NPC e conferir os valores 1×/3×/4× sobre as velocidades-base; conferir que as razões relativas entre veículos são idênticas nos três modos; reiniciar a corrida 5 vezes e conferir que as velocidades não crescem; observar que a contagem de 1 s da largada continua levando 1 s e que a partida começa sem aceleração instantânea.

**Acceptance Scenarios**:

1. **Given** modo Relaxante selecionado, **When** a corrida inicia, **Then** o jogador e todos os NPCs operam exatamente em suas velocidades-base (multiplicador 1,0×).
2. **Given** modo Normal selecionado, **When** a corrida inicia, **Then** a velocidade máxima efetiva do jogador é o triplo da base (125 → 375 km/h) e a de cada NPC é o triplo da sua base (caminhão/utilitário 90 → 270, passeio 100 → 300, esportivo 120 → 360 km/h).
3. **Given** modo Desafio selecionado, **When** a corrida inicia, **Then** a velocidade máxima efetiva do jogador é o quádruplo da base (125 → 500 km/h) e a de cada NPC é o quádruplo da sua base (90 → 360, 100 → 400, 120 → 480 km/h).
4. **Given** qualquer modo, **When** a corrida começa, **Then** a velocidade inicial é zero e a aceleração é gradual, com a mesma curva de aceleração/frenagem/direção do comportamento atual — sem aceleração instantânea nem mudança nos controles.
5. **Given** qualquer modo, **When** a corrida é reiniciada 5 vezes seguidas, **Then** as velocidades-base e efetivas da 5ª corrida são idênticas às da 1ª — zero acúmulo de multiplicação.
6. **Given** qualquer modo, **When** a largada executa a contagem de 1 s, **Then** a contagem leva cerca de 1 s de tempo real — temporizadores, transições de estado e interface não são acelerados pelo modo.
7. **Given** nenhuma seleção de modo válida, **When** uma corrida inicia, **Then** o modo efetivo é Normal (3,0×).
8. **Given** qualquer modo em andamento, **When** o jogador pausa e retoma, **Then** o multiplicador permanece exatamente o mesmo.
9. **Given** o menu inicial, **When** o jogador alterna o modo entre Relaxante, Normal e Desafio, **Then** a seleção é refletida antes do início da próxima corrida, Normal é o padrão inicial, e a troca não altera nenhuma corrida em andamento.

---

### User Story 2 - Avançar por ciclos infinitos de ambientes com dificuldade crescente (Priority: P2)

O jogo é infinito: os ambientes avançam por vitória na sequência **planície → deserto → floresta → gelo → planície…**. Vencer mostra a mensagem de vitória com exatamente duas opções: **"Continuar próxima fase"** (inicia a próxima corrida no ambiente seguinte, com o mesmo modo) e **"Voltar ao menu"**. Perder mostra a mensagem de Fim de Jogo com a única opção **"Voltar ao menu"** — a derrota zera o progresso do ciclo atual (a próxima corrida recomeça pela planície), mas preserva os bônus dos ciclos já concluídos na sessão. A cada ciclo completo — as quatro vitórias de planície, deserto, floresta e gelo — o próximo ciclo aplica a todos os veículos (jogador e NPCs) um aumento percentual de **0,002 (0,2%)** sobre a velocidade, deixando o trânsito mais veloz de cima para baixo e o desvio mais difícil.

**Why this priority**: É o arco de longa duração do jogo: sem a sequência infinita e o bônus, cada corrida seria sempre a mesma pista na mesma velocidade. Depende apenas do fluxo de vitória/derroda existente e do multiplicador de velocidade — não do balanceamento fino por modo.

**Independent Test**: Vencer as 4 corridas da sequência e conferir que a 5ª fase é planície com jogador e NPCs 0,2% mais rápidos; perder em qualquer ponto e conferir a tela de Fim de Jogo com a única opção "Voltar ao menu" e recomeço pela planície mantendo o bônus de ciclos concluídos; conferir as duas opções da vitória e a troca de ambiente a cada "Continuar próxima fase".

**Acceptance Scenarios**:

1. **Given** qualquer vitória, **When** a tela de vitória aparece, **Then** a mensagem de vitória é exibida com exatamente as opções "Continuar próxima fase" e "Voltar ao menu" — sem "Tentar novamente".
2. **Given** vitória na planície, **When** o jogador escolhe "Continuar próxima fase", **Then** a próxima corrida inicia no deserto, com o modo selecionado preservado, combustível e distância preparados do zero.
3. **Given** a sequência planície → deserto → floresta → gelo, **When** o gelo é vencido, **Then** a próxima fase é a planície de um novo ciclo, com o fator de bônus do novo ciclo já aplicado.
4. **Given** uma derrota em qualquer ambiente, **When** a tela de Fim de Jogo aparece, **Then** a mensagem é exibida com a única opção "Voltar ao menu"; ao iniciar uma nova corrida a partir do menu, a sequência recomeça pela planície e o bônus dos ciclos já concluídos permanece.
5. **Given** o primeiro ciclo (0 vitórias), **When** qualquer corrida roda, **Then** o fator de bônus de ciclo é 1,000 — nenhum aumento de velocidade por ciclo.
6. **Given** um ciclo completo (4 vitórias: planície, deserto, floresta e gelo), **When** o próximo ciclo inicia, **Then** jogador e NPCs recebem aumento percentual de 0,002 (fator 1,002) sobre `velocidade_base × multiplicador_do_modo`, preservando as razões entre os veículos; a cada novo ciclo completo o fator cresce mais 0,002 (1,004, 1,006, …).
7. **Given** qualquer modo, **When** o bônus de ciclo está ativo, **Then** ele se aplica igualmente em Relaxante, Normal e Desafio, sem alterar os fatores de balanceamento do modo.

---

### User Story 3 - Balancear trânsito, galões e penalidades pelo modo (Priority: P3)

Além da velocidade, cada modo ajusta a pressão da corrida: **Relaxante** reduz a densidade de trânsito, aumenta a disponibilidade de galões de combustível e reduz a perda de combustível por colisão; **Normal** mantém os valores atuais; **Desafio** aumenta a densidade (sem passar do limite máximo existente), escasseia os galões e amplia as penalidades. Todos os ajustes são aplicados por cima dos mecanismos já existentes de geração de trânsito, geração de galões e colisão — nenhum sistema novo é criado —, e nenhuma corrida deixa de ser concluível.

**Why this priority**: Sem este balanceamento, o multiplicador de velocidade sozinho produziria corridas desequilibradas (Normal/Desafio rápidos demais com trânsito e penalidades de 1×, ou Relaxante igual ao normal em pressão). É a diferença entre "mais rápido" e "modos de dificuldade jogáveis".

**Independent Test**: Comparar os parâmetros efetivos dos três modos e conferir a ordem esperada (densidade Relaxante < Normal < Desafio; frequência de galões Relaxante > Normal > Desafio; penalidade Relaxante < Normal < Desafio); rodar uma corrida de referência em cada modo e conferir que termina com combustível dentro da faixa de calibração.

**Acceptance Scenarios**:

1. **Given** os três modos, **When** os parâmetros efetivos são calculados, **Then** densidade-alvo de NPCs = 0,70× / 1,00× / 1,20×; frequência de galões = 1,50× / 1,00× / 0,65×; penalidade de combustível por colisão = 0,50× / 1,00× / 1,50×; distância mínima entre gerações de galões = 0,80× / 1,00× / 1,20× (Relaxante / Normal / Desafio).
2. **Given** modo Desafio com densidade-alvo acima do teto, **When** a densidade efetiva é aplicada, **Then** o limite máximo de NPCs existente é respeitado — nunca é ultrapassado.
3. **Given** qualquer modo, **When** uma colisão com NPC ocorre, **Then** a penalidade de combustível aplicada é a do ambiente vigente multiplicada pelo fator do modo, aplicada uma única vez, dentro dos limites do sistema de combustível (nunca negativa, nunca além dos limites configurados).
4. **Given** qualquer modo, **When** a geração de galões ocorre, **Then** a distância efetiva entre gerações é sempre positiva e respeita os limites técnicos, o posicionamento válido, o espaçamento e a quantidade máxima de itens já existentes.
5. **Given** qualquer modo, **When** uma corrida de referência é executada até o fim, **Then** ela é concluível com combustível, com sobra final dentro da faixa de calibração definida para o modo.
6. **Given** modo Desafio, **When** a corrida roda ao longo do tempo, **Then** a geração de NPCs continua funcionando (nascimentos seguem ocorrendo) — zero bloqueios permanentes de trânsito.

---

### User Story 4 - Combinar o modo com qualquer ambiente e integrar a seleção da SPEC-013 (Priority: P4)

O modo de jogo e a dificuldade do ambiente são eixos independentes: é possível jogar Relaxante no gelo, Normal no deserto ou Desafio na planície, e o nível numérico do ambiente (1–4) nunca entra no multiplicador de velocidade — cada ambiente mantém suas características próprias (decoração, penalidades ambientais, densidade base). O modo é definido antes da corrida, permanece constante do início ao fim dela, mudanças posteriores não afetam uma corrida em andamento e valem para a próxima; reiniciar reaplica o modo escolhido. A SPEC-009 entrega a superfície de integração de seleção que a SPEC-013 (menu de configurações) vai usar, e a interface exibe o modo ativo quando necessário.

**Why this priority**: É o que garante que a feature não contamine o sistema de ambientes existente, que a corrida seja previsível (configuração constante por corrida) e que a SPEC-013 futura consiga selecionar o modo sem reescrever nada. Depende do núcleo das US1/US2, mas cada parte é verificável de forma independente.

**Independent Test**: Executar as 12 combinações (4 ambientes × 3 modos) e confirmar que todas rodam com o multiplicador do modo e as características do ambiente preservadas; tentar trocar o modo durante uma corrida e confirmar que ela não muda; confirmar que Reiniciar reaplica o modo; confirmar que a interface futura consegue ler e definir o modo sem tocar nos sistemas de gameplay.

**Acceptance Scenarios**:

1. **Given** Relaxante no gelo, Normal no deserto e Desafio na planície, **When** cada corrida é executada, **Then** cada uma usa o multiplicador do seu modo e preserva as características do seu ambiente, sem interferência cruzada.
2. **Given** qualquer modo, **When** o ambiente muda de um nível de dificuldade para outro, **Then** o multiplicador de velocidade permanece exatamente o mesmo — a dificuldade do ambiente não entra no cálculo.
3. **Given** um modo definido antes da corrida, **When** a corrida está em andamento, **Then** a configuração efetiva permanece constante do início ao fim — nenhum sistema muda de parâmetros no meio da corrida.
4. **Given** uma corrida em andamento, **When** uma alteração de modo acontece fora da corrida, **Then** a corrida atual não é afetada; o novo valor vale para a próxima corrida.
5. **Given** qualquer modo, **When** o jogo percorre os estados `MENU`, `READY`, `PLAYING`, `PAUSED`, `VICTORY` e `GAME_OVER`, **Then** todos funcionam normalmente e a reinicialização reaplica a configuração do modo.
6. **Given** o menu de configurações futuro da SPEC-013, **When** ele definir o modo, **Then** a seleção é aplicada antes da próxima corrida sem nenhuma mudança nos sistemas de gameplay.

---

### Edge Cases

- Seleção de modo ausente, inválida ou corrompida → a corrida usa Normal (3,0×) com os valores padrão seguros; nenhuma falha de início.
- Tentativa de alterar o modo durante `PLAYING` ou `PAUSED` → a corrida em andamento mantém a configuração original; o valor novo só vale para a próxima corrida.
- Densidade-alvo do Desafio (1,20×) acima do limite máximo de NPCs → o teto existente prevalece; a densidade efetiva nunca o ultrapassa.
- Distância mínima entre gerações de galões com multiplicadores → o valor efetivo nunca fica zero, negativo ou abaixo do limite técnico aceitável; havendo conflito com o espaço mínimo, adia a geração em vez de gerar inválido.
- Reinício repetido, volta ao menu e nova partida no mesmo modo → velocidades-base e efetivas idênticas às da primeira corrida (zero acúmulo, zero sobrescrita da base).
- Relaxante (1,0×) → comportamento idêntico ao atual em velocidade, densidade, galões e penalidades; regressão zero em relação às SPEC-001–008.
- Corrida em Desafio (4,0× + densidade 1,20× + galões escassos) nos ambientes mais duros → a corrida continua concluível em testes de referência; nenhuma combinação pode tornar a pista impossível.
- Colisão a 3×/4× → a colisão é detectada no mesmo encontro (nada de atravessamento em que o NPC cruza o jogador sem contato registrado); penalidade aplicada uma única vez.
- Esgotamento de combustível a 3×/4× → desaceleração gradual até parar e `GAME_OVER` corretos; vitória continua exigindo combustível no cruzamento completo.
- Nascimentos de NPCs e geração de galões a 4× → seguem funcionando após reinícios e corridas longas; zero bloqueios permanentes e zero crescimento indefinido de objetos.
- Pausa/retomada em qualquer modo → multiplicador e parâmetros inalterados; nada avança nem escala durante `PAUSED`.
- Vitória no gelo → a próxima fase é sempre a planície de um novo ciclo (o gelo nunca se repete como próxima fase).
- Derrota em qualquer ponto da sequência → recomeço pela planície; os ciclos já concluídos e seu bônus não são perdidos; nenhum outro progresso é mantido além do bônus.
- "Continuar próxima fase" em qualquer modo → o modo selecionado é preservado na próxima corrida; a corrida nasce preparada do zero (distância zerada, tanque na carga inicial).
- Bônus de ciclo combinado com o modo → fator efetivo `velocidade_base × multiplicador_do_modo × (1 + 0,002 × ciclos_concluídos)`, aplicado uma única vez e sem acúmulo por reinício.
- Fechar e reabrir o jogo → todo o progresso de sequência, vitórias e ciclos é perdido (sem persistência — sessão apenas).
- Ciclo 1 → nenhuma corrida antes da 4ª vitória recebe aumento de velocidade por ciclo.

## Requirements *(mandatory)*

### Functional Requirements

**Modos e multiplicador de velocidade**

- **FR-001**: O jogo deve oferecer exatamente três modos de dificuldade — Relaxante (multiplicador 1,0×), Normal (3,0×) e Desafio (4,0×) —; quando não houver seleção válida de modo, o modo efetivo deve ser Normal.
- **FR-002**: Todos os parâmetros de dificuldade (multiplicadores do modo, parâmetros gerais por modo) devem ficar centralizados em uma fonte única de configuração, ajustáveis sem alteração da lógica, sem valores mágicos espalhados pelo código, e com valores padrão seguros quando a configuração ausente for inválida.
- **FR-003**: A velocidade-base de qualquer veículo nunca deve ser sobrescrita por valores já multiplicados: a velocidade efetiva resulta sempre de `velocidade_base × multiplicador_do_modo`, calculada em um único ponto da arquitetura por uma interface compartilhada, com aplicação única — o multiplicador não pode ser aplicado duas vezes em atualizações, pausas, reinícios ou reexecuções.
- **FR-004**: O multiplicador deve afetar a velocidade efetiva máxima do jogador (125 km/h de base → 125/375/500 km/h em Relaxante/Normal/Desafio), preservando integralmente os controles (aceleração, frenagem, direção), a aceleração gradual, a desaceleração, as regras de falta de combustível e as regras de colisão; a largada não pode começar com velocidade instantânea.
- **FR-005**: O mesmo multiplicador deve afetar todos os tipos de NPC (caminhão 90 km/h, utilitário 90 km/h, passeio 100 km/h, esportivo 120 km/h de base → respectivamente 90/270/360, 90/270/360, 100/300/400, 120/360/480 km/h nos três modos), preservando as diferenças relativas entre as velocidades-base; NPCs já ativos na pista e novos nascimentos devem refletir o modo da corrida; a memória de spawn, o mecanismo de geração e o limite máximo de NPCs permanecem inalterados.
- **FR-006**: A configuração efetiva de uma corrida deve ser consistente do início ao fim: definida antes do início, aplicada antes de os sistemas dependentes operarem, imutável durante a corrida (inclusive sob pausa), e reaplicada corretamente ao reiniciar — sem acúmulo de multiplicação entre corridas.
- **FR-007**: O multiplicador deve afetar apenas o movimento dos veículos (e a rolagem/distância derivadas dele), nunca o relógio global do jogo: contagem de largada, transições de estado, temporizadores de interface, animações, eventos de vitória e Game Over e demais tempos continuam no tempo real; a distância percorrida deve continuar coerente com a velocidade efetiva e a contagem de distância não pode ser acelerada nem duplicada pelo modo.

**Parâmetros gerais de dificuldade**

- **FR-008**: O modo deve ajustar a densidade-alvo de NPCs pelos fatores 0,70× / 1,00× / 1,20× (Relaxante/Normal/Desafio), utilizando o mecanismo de densidade existente e respeitando sempre o limite máximo de NPCs já configurado; a implementação não pode criar um novo mecanismo de controle de quantidade nem de memória de spawn.
- **FR-009**: O modo deve ajustar a frequência de geração de galões de combustível pelos fatores 1,50× / 1,00× / 0,65×, respeitando todas as regras existentes de posicionamento, espaçamento, quantidade máxima de itens ativos, piso/teto por corrida e geração apenas em `PLAYING`.
- **FR-010**: O modo deve ajustar as penalidades de combustível por colisão pelos fatores 0,50× / 1,00× / 1,50×, combinados com a penalidade do ambiente vigente (fator efetivo = penalidade do ambiente × fator do modo), preservando a detecção e a resolução de colisões, a autoridade do sistema de combustível e a aplicação única por colisão.
- **FR-011**: O modo deve ajustar a distância mínima entre gerações de galões pelos fatores 0,80× / 1,00× / 1,20×; a distância efetiva deve permanecer sempre positiva e dentro dos limites técnicos da implementação.
- **FR-012**: Os valores da tabela de parâmetros (fatores por modo) devem ser os valores iniciais de balanceamento, calibráveis pela configuração sem alterar a lógica, e a implementação deve incluir testes de balanceamento e regressão que validem esses fatores e a estabilidade em 3× e 4×.

**Integrações preservadas (combustível, colisão, estados)**

- **FR-013**: Em qualquer modo, as regras de combustível permanecem intactas: o consumo deve ser coerente com a velocidade efetiva sem aplicar o multiplicador duas vezes ao consumo; a coleta não ultrapassa a capacidade do tanque; a falta de combustível impede novas acelerações e desacelera o veículo gradualmente; o Game Over ocorre ao parar sem combustível sem ter concluído; a vitória exige cruzar completamente a chegada com combustível — nenhum modo pode ignorar essas condições.
- **FR-014**: Em qualquer modo, os sistemas de colisão jogador×NPC e NPC×NPC permanecem preservados: detecção, resolução, velocidade relativa, colisões em cadeia e limites dinâmicos da estrada funcionando em 3× e 4×, sem atravessamento de veículos (nenhum NPC cruza o jogador sem contato detectado), com penalidade aplicada uma única vez e sem penalidade ambiental duplicada.
- **FR-015**: O modo e a dificuldade do ambiente devem ser independentes: o multiplicador vem apenas do modo, vale igualmente em todos os quatro ambientes (PLAINS/DESERT/FOREST/ICE), e o nível numérico do ambiente não pode entrar no multiplicador de velocidade; cada ambiente mantém suas características próprias (decoração, obstáculos, penalidades ambientais).
- **FR-016**: O modo deve ser definido antes do início da corrida e aplicado antes de os sistemas dependentes iniciarem suas operações; alterações feitas fora da corrida não podem modificar inesperadamente uma corrida em andamento (valem para a próxima); Reiniciar deve reaplicar corretamente o modo selecionado; e a seleção deve ser possível pelo jogador por um seletor mínimo no menu atual (Relaxante, Normal e Desafio, com Normal como padrão), funcionando como placeholder até a SPEC-013 entregar o menu de configurações completo.
- **FR-017**: A SPEC-009 deve disponibilizar a superfície de integração que a SPEC-013 usará para selecionar o modo, e a interface deve exibir o modo ativo quando necessário (por exemplo, no menu ou na largada), sem a implementação do menu completo desta spec.
- **FR-018**: A implementação deve integrar-se às SPEC-001 a SPEC-008 sem regressões: controles, colisões, deriva, NPCs, trânsito, decoração, ambientes, estrada, combustível, progressão e estados continuam funcionando; nenhuma velocidade-base, limite de segurança ou asset é modificado; e nenhum sistema paralelo de trânsito, combustível ou colisão é criado.

**Progressão infinita e fluxos de fim de corrida**

- **FR-019**: O jogo deve ser infinito: os ambientes avançam por vitória na sequência fixa planície → deserto → floresta → gelo → planície → …, cada vitória avançando exatamente uma posição — ao vencer o gelo, a próxima fase é a planície de um novo ciclo.
- **FR-020**: A tela de vitória deve apresentar a mensagem de vitória e exatamente duas opções: "Continuar próxima fase" (inicia a próxima corrida no ambiente seguinte da sequência, com o modo selecionado preservado e a corrida preparada do zero) e "Voltar ao menu" — substituindo o "Tentar novamente" da SPEC-008.
- **FR-021**: A tela de Fim de Jogo (Game Over) deve apresentar a mensagem de fim de jogo e somente a opção "Voltar ao menu" — sem "Tentar novamente", substituindo o comportamento da SPEC-008.
- **FR-022**: A cada ciclo completo — quatro vitórias na sequência planície, deserto, floresta e gelo — o próximo ciclo deve aplicar a jogador e NPCs um aumento percentual de 0,002 (0,2%) sobre a velocidade, segundo o fator de ciclo `1 + 0,002 × ciclos_concluídos` (ciclo 1: 1,000; ciclo 2: 1,002; ciclo 3: 1,004; …), aplicado sobre `velocidade_base × multiplicador_do_modo`, preservando as razões relativas entre os veículos — o efeito pretendido é perceptível: trânsito descendo mais rápido de cima para baixo e maior dificuldade de desvio; o fator deve ser configurável.
- **FR-023**: A derrota deve zerar o progresso do ciclo atual — a próxima corrida começa na planície —, preservando apenas os ciclos já concluídos e o bônus acumulado deles; todo o progresso (posição na sequência, vitórias do ciclo atual e ciclos concluídos) deve viver apenas na sessão de jogo, sem persistência entre execuções — recordes e persistência permanecem fora do escopo.

### Key Entities

- **Modo de Jogo**: identificação do modo (Relaxante, Normal, Desafio) e seu conjunto de parâmetros — multiplicador de velocidade, fator de densidade-alvo de NPCs, fator de frequência de galões, fator de penalidade de combustível por colisão e fator de distância mínima entre gerações de galões.
- **Configuração Efetiva da Corrida**: o modo vigente combinado com o ambiente da corrida, resultando nos valores finais que cada sistema de gameplay utiliza durante aquela corrida — definida antes do início, constante durante toda a corrida e reaplicada a cada reinício.
- **Progresso da Sessão**: a posição atual na sequência de ambientes, as vitórias acumuladas do ciclo atual e os ciclos concluídos — determinam o próximo ambiente da sequência e o fator de bônus de velocidade do próximo ciclo; vive apenas enquanto o jogo está aberto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das corridas, cada modo aplica exatamente o seu multiplicador à velocidade máxima base do jogador — Relaxante 125 km/h, Normal 375 km/h, Desafio 500 km/h — com desvio menor de 1% em relação ao valor teórico.
- **SC-002**: Em 100% das medições, cada tipo de NPC opera a 1×/3×/4× da sua velocidade-base (90, 90, 100 e 120 km/h) e as razões relativas entre os tipos são idênticas nos três modos (desvio < 1%); após 5 reinícios consecutivos, 0 acréscimos acumulados nas velocidades-base e 0 sobrescritas da base por valores multiplicados.
- **SC-003**: Temporizadores e estados não são acelerados pelo modo: a contagem de largada varia menos de 1% entre os três modos; as curvas de aceleração/frenagem normalizadas coincidem entre modos com desvio < 1%; a partida inicia com velocidade zero em 100% das corridas; e os controles permanecem os mesmos 4 ações com os mesmos efeitos em 100% dos modos.
- **SC-004**: A contagem de distância permanece coerente: a distância total é a mesma nos três modos, a distância percorrida nunca ultrapassa o total (0 ocorrências) e 0 acréscimos de distância são gerados por temporizadores ou estados — apenas pelo movimento efetivo.
- **SC-005**: Trânsito: a densidade efetiva obedece à ordem Relaxante < Normal < Desafio em 100% das comparações de configuração; o limite máximo de NPCs é respeitado em 100% dos quadros (0 ultrapassagens); a geração de NPCs continua ocorrendo após reinícios e em corridas longas — 0 bloqueios permanentes.
- **SC-006**: Galões: a frequência efetiva obedece à ordem Relaxante > Normal > Desafio em 100% das comparações; a distância efetiva entre gerações é positiva em 100% dos casos; piso/teto por corrida e quantidade máxima ativa respeitados em 100% das corridas; 0 gerações fora de `PLAYING` ou fora da pista válida.
- **SC-007**: Penalidades: em 100% das colisões de referência, a perda de combustível aplicada é exatamente `penalidade_do_ambiente × fator_do_modo` (desvio < 1%) e aplicada uma única vez — 0 penalidades duplicadas em qualquer modo.
- **SC-008**: Combustível: 100% das corridas de referência de cada modo são concluíveis com sobra final dentro da faixa de calibração; 100% das vitórias ocorrem com combustível > 0 no cruzamento completo; 100% dos Game Over ocorrem com combustível = 0 e corrida não concluída; 0 acréscimos de combustível além da capacidade do tanque.
- **SC-009**: Colisões: 100% das colisões de referência continuam detectadas em 3× e 4×, com 0 atravessamentos não detectados, resolução estável (0 duplicações de evento de colisão) e velocidade relativa calculada corretamente em todas as faixas de velocidade dos três modos.
- **SC-010**: Estados: 100% das transições entre `MENU`, `READY`, `PLAYING`, `PAUSED`, `VICTORY` e `GAME_OVER` funcionam em qualquer modo; pausa/retomada alteram o multiplicador em 0 ensaios; reinício reaplica a configuração em 100% dos casos.
- **SC-011**: Ambientes: 100% das 12 combinações (4 ambientes × 3 modos) executam corridas de referência sem falha; trocar de modo produz 0 mudanças nas características do ambiente (decoração, penalidade ambiental, nível de dificuldade).
- **SC-012**: Padrão: com seleção de modo ausente ou inválida, 100% das corridas iniciam em Normal (3,0×).
- **SC-013**: Estabilidade: no cenário máximo (Desafio: 4,0× de velocidade + 1,20× de densidade), 0 travamentos, 0 crescimentos indefinidos de NPCs ou galões e nenhuma corrida de referência se torna inconcluível.
- **SC-014**: Fluxos de fim de corrida: em 100% das vitórias, a tela oferece exatamente 2 opções ("Continuar próxima fase" e "Voltar ao menu") — 0 ocorrências de "Tentar novamente"; em 100% dos Game Over, a tela oferece exatamente 1 opção ("Voltar ao menu").
- **SC-015**: Sequência: em 100% das vitórias, o ambiente avança exatamente 1 posição na ordem planície → deserto → floresta → gelo → planície; o ciclo completo é reconhecido a cada 4 vitórias (planície, deserto, floresta e gelo) — 0 saltos, 0 repetições indevidas e 0 vitórias fora de sequência.
- **SC-016**: Bônus de ciclo: em 100% das medições, a velocidade efetiva de jogador e NPCs segue `velocidade_base × multiplicador_do_modo × (1 + 0,002 × ciclos_concluídos)` com desvio menor de 1%; ciclo 1 = 1,000 exato; as razões relativas entre os veículos variam menos de 1% entre ciclos; 0 aplicações duplas após reinícios ou voltas ao menu.
- **SC-017**: Derrota: em 100% das derrotas, a corrida seguinte inicia na planície com o fator de bônus dos ciclos concluídos intacto — 0 perdas de bônus e 0 recomeços fora da planície após derrota.

## Assumptions

- Não existe hoje nenhum sistema de modo de jogo no projeto (a dificuldade existente é a dificuldade do ambiente, 1–4) — o novo ponto central de dificuldade é a fonte única dos parâmetros do modo, seguindo o princípio da constituição de dificuldade orientada por configuração.
- **Normal é o modo padrão** quando não há seleção válida — decisão explícita da especificação; até que uma seleção seja feita, todas as corridas rodam a 3,0×.
- A SPEC-013 (menu de configurações) ainda não existe; até lá a seleção é feita por um seletor mínimo no menu atual (decisão Q1: opção A — placeholder até a SPEC-013), que a SPEC-013 substituirá; esta spec entrega também a superfície de integração e a exibição do modo ativo — a interface completa é da SPEC-013.
- Os valores da tabela de parâmetros (0,70/1,00/1,20; 1,50/1,00/0,65; 0,50/1,00/1,50; 0,80/1,00/1,20) são os valores iniciais sugeridos; o balanceamento fino é feito por calibração configurável sem mudar a lógica.
- A combinação modo × ambiente é multiplicativa por cima dos valores já existentes (o ambiente continua mandando nas suas próprias características, incluindo a penalidade de colisão que o fator do modo multiplica).
- O consumo de combustível não recebe um multiplicador próprio de modo: a coerência com a velocidade efetiva é obrigatória (nada de aplicação dupla), mantida a fórmula de dimensionamento por distância da SPEC-008.
- **Faixa de calibração (SC-008 e cenário 5 da US3)**: sobra final de combustível de uma corrida de referência entre **15% e 35% da capacidade do tanque** — **a mesma faixa vale para Relaxante, Normal e Desafio** (não há faixa por modo) — valores iniciais, ajustáveis pela calibração do quickstart §5 sem alterar a lógica; as suítes automatizadas validam relações/invariantes, e a faixa é conferida no aceite manual.
- Velocidades-base consideradas: jogador 125 km/h; NPCs caminhão/utilitário 90, passeio 100, esportivo 120 km/h — conforme a configuração atual do projeto.
- Fora de escopo (conforme o texto da spec): novo gerador/limite/memória de spawn de NPCs, reimplementação de combustível/colisão, menu completo, som e recordes — os sistemas existentes recebem os parâmetros.
- **Adendo do usuário (2026-10-12), resolvido em perguntas Q1–Q3**: (Q1-A) a tela de Fim de Jogo tem somente "Voltar ao menu" — sem "Tentar novamente"; (Q2-B) a derrota zera o progresso do ciclo atual, mantendo apenas os bônus dos ciclos concluídos; (Q3-C) o aumento por ciclo é um **percentual de 0,002 (0,2%)** com fator aditivo `1 + 0,002 × ciclos_concluídos` — objetivo: trânsito mais rápido de cima para baixo e desvio mais difícil.
- Os fluxos da vitória e do Fim de Jogo **substituem** o "Tentar novamente" das duas telas previsto no FR-034 da SPEC-008.
- "Continuar próxima fase" preserva o modo selecionado e inicia a próxima corrida do zero (reset da SPEC-008: distância zerada, tanque na carga inicial).
- O progresso de sequência/ciclos não é persistido em disco — vive apenas na sessão; persistência e recordes permanecem fora do escopo desta spec.
