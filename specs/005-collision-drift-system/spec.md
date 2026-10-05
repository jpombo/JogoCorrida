# Feature Specification: Sistema de Colisão e Drift

**Feature Branch**: `005-collision-drift-system`

**Created**: 2026-10-04

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-005 — Sistema de Colisão e Drift" (detecção e consequências arcade de colisão entre o jogador e os NPCs do trânsito: perda de velocidade, drift lateral, recuperação gradual, ultrapassagem do NPC, cooldown, evento de colisão e hitboxes independentes dos sprites).

## Clarifications

### Session 2026-10-05

- Q: Qual é a fonte oficial dos "cenários de teste obrigatórios" citados no SC-002 ("tabela da seção 23 da descrição")? → A: Os cenários de aceitação das User Stories deste spec (US1–US7) são a referência oficial; o spec é autocontido.
- Q: O que "sem penalização significativa de velocidade" significa para o NPC na colisão lateral? → A: Perda zero exata: o NPC nunca perde velocidade em nenhuma colisão, alinhando US2-CA3 ao Out of Scope e ao FR-017.
- Q: Qual é o critério objetivo de "suficiente para viabilizar a ultrapassagem em pista livre" (FR-019)? → A: Ao fim do deslocamento, as hitboxes não se intersectam mais e o NPC termina à frente do jogador no eixo do percurso.

### Session 2026-10-05 (ajustes pós-implementação — testes manuais)

- Q: Ao colidir, o jogador é empurrado para trás, mas se estiver segurando a aceleração ele volta imediatamente à mesma posição — como tratar? → A: A aceleração passa a ser **desconsiderada** por uma janela de tempo configurável contada a partir do impacto; a frenagem continua valendo durante toda a janela e, expirada ela, a aceleração volta a operar normalmente. Registrado como FR-036 e SC-013, com o parâmetro na lista de FR-035.
- Q: Os outros quatro ajustes observados nos mesmos testes manuais (separação no nascimento de NPCs, velocidades de categoria por corredor, densidade mínima de veículos e travamento de caminhão na velocidade do esporte) pertencem a esta spec? → A: Não — são ajustes de comportamento do sistema de trânsito e estão registrados na spec do SPEC-004 (sessão de clarificações de 2026-10-05, FR-063/FR-064/FR-065, SC-028/SC-029/SC-030). Aqui ficam apenas como contexto do teste manual em que foram descobertos.

### Session 2026-10-05 (ajuste 6 — bug de velocidades divergentes após colisão)

- Q: Após colisões, caminhões passam a se mover na taxa de passeio (80 px/s em vez de 72 px/s), fazendo NPCs de categorias diferentes atingirem velocidades aparentemente diferentes. Qual a causa e como tratar? → A: Causa raiz: o deslocamento de ultrapassagem (40 px) era permanente — o NPC ficava fora da faixa reservada da sua velocidade, caía no corredor de outra categoria e o limitador de espaçamento acoplava os dois à mesma taxa. Tratativa registrada como **ajuste 6**: reforço de FR-021 com retorno literal à faixa de origem, duração do retorno configurável (lista de FR-035), critério objetivo em SC-014 e emenda do caso de borda "NPC deslocado colado à borda da pista durante a ultrapassagem" (ida travada na borda ainda retorna à origem). Implementado em 2026-10-05.
- Q: A regra de direção do movimento livre (jogador mais rápido → NPC desce ao final; NPC mais rápido → sobe ao topo, FR-016/SC-003) deve mudar com o ajuste 6? → A: Não — **manter o sinal atual** da regra; o ajuste 6 apenas devolve o NPC à faixa ao fim do draft, sem tocar na lógica de quem passa para quem.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Colidir com a traseira de um NPC e absorver o impacto (Priority: P1)

O jogador está avançando mais rápido que um NPC à sua frente e atinge a traseira dele. O jogo detecta a batida, classifica como "jogador atinge traseira do NPC", reduz a velocidade do jogador e aplica um deslocamento lateral (drift) para o lado em que o jogador estava em relação ao NPC: bateu pela esquerda, sai pela esquerda; bateu pela direita, sai pela direita. O NPC segue sua trajetória sem penalização de velocidade.

**Why this priority**: É a colisão mais comum num jogo de perseguição vertical e o núcleo do comportamento arcade pedido — detecção, classificação, perda de velocidade e drift. Sem ela, as demais situações não têm base. É o MVP.

**Independent Test**: Com um único NPC à frente, acelerar até atingir sua traseira pelo lado esquerdo e depois pelo direito, observando a perda de velocidade e a direção do drift em cada caso. Validável sem nenhuma outra história implementada. Corresponde aos CAs 01, 02 e 03.

**Acceptance Scenarios**:

1. **Given** o jogador atrás de um NPC e mais rápido que ele, **When** as áreas físicas dos dois se intersectam, **Then** uma colisão válida é registrada, o jogador perde velocidade proporcional ao impacto e recebe drift lateral.
2. **Given** o jogador à esquerda do NPC no momento do impacto, **When** a colisão ocorre, **Then** o drift empurra o jogador para a esquerda.
3. **Given** o jogador à direita do NPC no momento do impacto, **When** a colisão ocorre, **Then** o drift empurra o jogador para a direita.
4. **Given** a mesma colisão, **When** ela termina, **Then** a velocidade do NPC não foi reduzida como consequência principal.
5. **Given** apenas os limites de 2 vias ou de 4 vias, **When** o jogador é deslocado pelo drift, **Then** ele nunca ultrapassa os limites válidos da estrada naquela altura.

---

### User Story 2 - Sofrer contato lateral com um NPC (Priority: P1)

O jogador e um NPC se tocam predominantemente pelas laterais (mudança de faixa encostada). O jogo classifica como colisão lateral e aplica ao jogador perda de velocidade e drift para o lado em que ele se encontra em relação ao NPC, sem nenhuma redução de velocidade ao NPC.

**Why this priority**: É o segundo tipo de contato mais frequente e compartilha a regra de direção da US1, mas exige classificação distinta — sem ela, ultrapassagens raspando teriam comportamento errado ou ausente.

**Independent Test**: Aproximar-se de um NPC pela lateral, dos dois lados, e observar a classificação "colisão lateral" e o drift na direção correta. Corresponde ao CA-04.

**Acceptance Scenarios**:

1. **Given** o jogador à esquerda do NPC, **When** os dois colidem lateralmente, **Then** o drift do jogador é para a esquerda.
2. **Given** o jogador à direita do NPC, **When** os dois colidem lateralmente, **Then** o drift do jogador é para a direita.
3. **Given** uma colisão lateral, **When** ela é processada, **Then** a velocidade do NPC permanece exatamente a mesma antes e depois da colisão.
4. **Given** uma mesma faixa ocupada por dois veículos colados, **When** a diferença lateral está dentro da margem neutra configurada, **Then** a direção do drift é decidida de forma determinística e estável, sem oscilar entre os lados.

---

### User Story 3 - Ser atingido na traseira por um NPC mais rápido e vê-lo ultrapassar (Priority: P1)

O jogador está mais lento e um NPC mais rápido alcança sua traseira. O jogador perde velocidade e sofre drift pelo seu lado relativo ao NPC; o NPC **não** perde velocidade e recebe um deslocamento lateral temporário para o lado oposto, completando a ultrapassagem e retomando sua trajetória.

**Why this priority**: É o comportamento especial mais característico do spec (ultrapassagem arcade) e a resposta à frustração de "o NPC bateu em mim e também apanhou junto". Inverte os papéis da US1 e é o caso mais rico em regras obrigatórias.

**Independent Test**: Reduzir a velocidade e aguardar um NPC mais rápido atingir a traseira, com o jogador uma vez à esquerda e outra à direita do NPC; verificar drift do jogador, deslocamento oposto do NPC, ultrapassagem concluída e velocidade do NPC inalterada. Corresponde ao CA-05.

**Acceptance Scenarios**:

1. **Given** o jogador à esquerda do NPC que o atinge por trás, **When** a colisão ocorre, **Then** o jogador sofre drift para a esquerda e o NPC se desloca para a direita, ultrapassando pela direita.
2. **Given** o jogador à direita do NPC que o atinge por trás, **When** a colisão ocorre, **Then** o jogador sofre drift para a direita e o NPC se desloca para a esquerda, ultrapassando pela esquerda.
3. **Given** uma colisão "NPC atinge jogador", **When** ela é processada, **Then** a velocidade do NPC permanece a mesma antes e depois da colisão.
4. **Given** o NPC deslocado durante a ultrapassagem, **When** a pista tem 2 vias, 4 vias ou está em transição, **Then** o deslocamento permanece dentro dos limites válidos da estrada.
5. **Given** a ultrapassagem concluída, **When** o efeito termina, **Then** o NPC retoma sua trajetória normal, sem drift permanente, dano ou perda de controle.

---

### User Story 4 - Recuperar o controle gradualmente após o drift (Priority: P1)

Após qualquer colisão, o jogador passa por um estado temporário de drift: continua podendo corrigir a trajetória com esquerda/direita, mas com influência reduzida; a influência do impacto diminui gradualmente até o controle voltar a 100%. O drift tem duração limitada.

**Why this priority**: Drift sem recuperação seria punição permanente; drift sem controle parcial transformaria o carro em objeto incontrolável — os dois quebram a promessa arcade da spec. É a história que transforma o evento instantâneo em experiência de gameplay.

**Independent Test**: Provocar uma colisão e, durante o drift, tentar corrigir a trajetória: a resposta deve existir, porém reduzida, e voltar ao normal gradualmente. Corresponde ao CA-07.

**Acceptance Scenarios**:

1. **Given** uma colisão válida, **When** o drift começa, **Then** o jogador tem o controle reduzido ao fator configurado (ex.: 40%) e o deslocamento do impacto prevalece parcialmente.
2. **Given** o drift em curso, **When** o tempo passa, **Then** a influência do impacto diminui gradualmente e o controle retorna progressivamente até 100%.
3. **Given** o fim da duração do drift, **When** o estado expira, **Then** o comportamento do veículo é idêntico ao de antes da colisão.
4. **Given** o jogador em drift, **When** ele não toca em nenhum controle, **Then** o deslocamento lateral do impacto acontece na direção classificada, limitado pelos limites da estrada.

---

### User Story 5 - Não ser penalizado duas vezes pela mesma batida (Priority: P2)

Enquanto as áreas físicas dos dois veículos permanecem sobrepostas, a mesma colisão não pode gerar novas perdas de velocidade nem novos drifts. Um cooldown configurável, controlado por veículo envolvido, separa colisões distintas de re-detecções do mesmo impacto.

**Why this priority**: Sem cooldown, uma única batida esmaga o jogador com penalizações em sequência — quebra de justiça perceptível. É P2 porque a experiência central (US1–US4) já entrega valor; a robustez vem aqui.

**Independent Test**: Forçar uma colisão e manter os veículos sobrepostos por alguns instantes: exatamente uma penalização é aplicada; um segundo NPC distinto encostando no jogador durante o cooldown do primeiro ainda gera sua própria colisão. Corresponde ao CA-08.

**Acceptance Scenarios**:

1. **Given** dois veículos sobrepostos após uma colisão, **When** o quadro seguinte ainda os mostra sobrepostos, **Then** nenhuma nova penalização é aplicada antes do fim do cooldown.
2. **Given** o cooldown do NPC anterior ainda ativo, **When** um NPC diferente colide com o jogador, **Then** a nova colisão é processada normalmente.
3. **Given** o cooldown encerrado e os veículos ainda sobrepostos, **When** o sistema reavalia, **Then** o comportamento é definido e documentado (nova colisão somente após os veículos se separarem e voltarem a se tocar — ver Assumptions).

---

### User Story 6 - Reagir à colisão a partir de outros sistemas (Priority: P2)

Sistemas futuros (combustível, feedback visual/sonoro, dificuldade) precisam saber quando uma colisão aconteceu, com quem, de que tipo e com que intensidade — sem acoplar-se à lógica de colisão. Toda colisão válida emite um evento com esses dados, e o sistema de colisão nunca modifica combustível diretamente.

**Why this priority**: É o contrato de integração pedido pela spec e pela constituição (arquitetura modular, comunicação por eventos). Não muda a experiência imediata, mas destrava os próximos specs.

**Independent Test**: Provocar colisões dos três tipos e capturar os eventos emitidos, conferindo tipo, intensidade, direção do drift e veículos envolvidos em cada um. Corresponde ao CA-09.

**Acceptance Scenarios**:

1. **Given** qualquer colisão válida, **When** ela é processada, **Then** um evento é emitido com os veículos envolvidos, o tipo de colisão, a velocidade de impacto, a direção do drift e a intensidade do impacto.
2. **Given** os três tipos de colisão, **When** ocorrem, **Then** o evento distingue "jogador atinge traseira do NPC", "colisão lateral" e "NPC atinge traseira do jogador".
3. **Given** colisões durante o cooldown, **When** são ignoradas, **Then** nenhum evento é emitido para elas.

---

### User Story 7 - Colidir com hitboxes independentes dos sprites (Priority: P2)

A detecção usa áreas físicas próprias, configuráveis por veículo, e não a aparência. Trocar o sprite ou ajustar a imagem de um veículo não muda como ele colide, e a área física representa a parte relevante do veículo, sem sobras transparentes.

**Why this priority**: Os assets já foram reorganizados uma vez (SPEC-004) e a spec exige essa independência; é também o que mantém a colisão estável quando a arte evoluir. Menor que P1 porque com os assets atuais a diferença é invisível ao jogador.

**Independent Test**: Alterar o sprite de um NPC para uma imagem de tamanho diferente e confirmar que a área de colisão e os resultados das batidas não mudam. Corresponde ao CA-10.

**Acceptance Scenarios**:

1. **Given** hitboxes configuradas para o jogador e para cada categoria de NPC, **When** a colisão é detectada, **Then** ela usa exclusivamente essas áreas configuradas.
2. **Given** a troca do sprite de um veículo por outro de dimensão distinta, **When** nenhuma configuração é tocada, **Then** a lógica e os resultados de colisão permanecem idênticos.
3. **Given** um caminhão e um carro de passeio, **When** colidem com o jogador nas mesmas condições relativas, **Then** apenas a área física configurada de cada um define onde o contato acontece.

---

### User Story 8 - Preservar o funcionamento das features anteriores (Priority: P1)

Com o sistema de colisão ativo, tudo que já existe — controle do veículo, scrolling da estrada, transições de 2↔4 vias, ambientes, trânsito e decoração — continua funcionando como antes. A colisão se soma à experiência sem alterar os comportamentos anteriores quando não há contato.

**Why this priority**: A constituição exige que a funcionalidade existente continue funcionando; é o guarda-chuva de não-regressão da feature.

**Independent Test**: Jogar sem colidir e validar que direção, velocidade, estrada, trânsito e decoração se comportam exatamente como nas specs anteriores. Valida o CA-06 no contexto completo e cobre a suíte de regressão.

**Acceptance Scenarios**:

1. **Given** uma partida sem nenhuma colisão, **When** o jogador acelera, freia e vira, **Then** o comportamento é idêntico ao do SPEC-001.
2. **Given** transições de largura durante a partida, **When** não há contato, **Then** trânsito e decoração comportam-se como no SPEC-004.
3. **Given** uma batida em cada ambiente, **When** a pista tem 2 vias, 4 vias ou transição, **Then** nenhum veículo sai dos limites trafegáveis (CA-06).

---

### Edge Cases

- **Colisão com o jogador exatamente no alinhamento do NPC**: a diferença lateral cai dentro da margem neutra configurada; a direção do drift é decidida de forma determinística e estável (ver premissa), nunca alternando lados por ruído de ponto flutuante.
- **Colisão durante o drift de outra batida**: uma nova colisão é válida (outro impacto), mas respeita o cooldown do seu próprio veículo; o drift resultante substitui o anterior pela última classificação.
- **Jogador praticamente parado atingido por trás**: a intensidade usa a velocidade relativa, então o impacto é proporcional mesmo com o jogador em baixa velocidade; o jogador nunca fica com velocidade abaixo de zero.
- **NPC deslocado colado à borda da pista durante a ultrapassagem**: o deslocamento é limitado aos limites válidos da estrada; se não houver espaço lateral para a ultrapassagem no lado oposto, o deslocamento para no limite e a ultrapassagem ocorre assim que houver espaço — ainda que a ida tenha travado na borda sem atingir a magnitude, o retorno leva o NPC de volta ao x da sua faixa de origem (FR-021).
- **Colisão durante a transição 2↔4 vias**: os limites consultados são os da altura de cada veículo naquele instante; nenhum deslocamento usa largura fixa memorizada.
- **Sobreposição persistente após o cooldown**: os veículos seguem no estado esperado pelo cooldown sem penalizações adicionais; uma nova colisão só ocorre se houver separação e novo contato.
- **Caminhão (área física maior)**: comprimentos maiores mudam apenas onde o contato acontece; tipo, regra de direção e consequências são idênticos para todas as categorias.
- **Múltiplos NPCs simultâneos**: cada par jogador↔NPC é avaliado com seu próprio cooldown; dois NPCs encostando no jogador no mesmo instante geram duas colisões válidas distintas.
- **Colisão lateral com velocidades longitudinalmente iguais**: o contato persiste ao longo do tempo; a margem neutra e o cooldown impedem penalizações ou alternâncias repetidas.
- **Desempenho**: a detecção roda a cada quadro sem degradar a meta de 60 FPS (piso 30 FPS) já estabelecida, com trânsito e decoração ativos.
- **Colisão com o jogador acelerando**: durante a janela de desconsideração da aceleração pós-impacto (FR-036), segurar o acelera não repõe a perda de velocidade — por isso o jogador permanece atrás por alguns instantes em vez de voltar direto à posição de antes; segurar o freio continua freando normalmente, e a janela é inerte quando não há colisão.

## Requirements *(mandatory)*

### Functional Requirements

**Detecção e classificação**

- **FR-001**: O sistema deve detectar a colisão entre o veículo do jogador e cada veículo de trânsito ativo, avaliando a interseção das áreas físicas (hitboxes) dos dois, a cada quadro em que a partida está em curso.
- **FR-002**: Toda colisão detectada deve ser classificada antes de qualquer consequência em exatamente um de três tipos: jogador atinge a traseira do NPC; colisão lateral; NPC atinge a traseira do jogador.
- **FR-003**: A classificação deve usar a posição relativa entre os veículos no espaço do jogo, e não uma direção fixa de movimento predefinida.
- **FR-004**: A direção lateral do drift deve derivar da posição horizontal relativa do jogador em relação ao NPC (jogador à esquerda → drift à esquerda; à direita → drift à direita).
- **FR-005**: Quando a diferença horizontal estiver dentro de uma margem neutra configurável em torno de zero, a direção deve ser resolvida de forma determinística e estável, sem oscilar por variações mínimas de posição.

**Áreas físicas (hitboxes)**

- **FR-006**: A colisão deve usar áreas físicas próprias, independentes do tamanho visual dos sprites.
- **FR-007**: As áreas físicas devem ser configuráveis para o jogador e para cada categoria de veículo de trânsito.
- **FR-008**: A troca ou o redimensionamento de um sprite não deve alterar a lógica nem o resultado da colisão sem mudança explícita de configuração.

**Consequências para o jogador**

- **FR-009**: Toda colisão válida deve reduzir a velocidade do jogador num valor proporcional à intensidade do impacto, dentro de um intervalo mínimo/máximo configurável.
- **FR-010**: A velocidade do jogador nunca deve ficar abaixo de zero em razão de uma colisão, e nenhuma colisão deve parar o veículo instantaneamente.
- **FR-011**: Toda colisão válida deve aplicar ao jogador um deslocamento lateral temporário (drift) na direção definida por FR-004/FR-005.
- **FR-012**: A intensidade do drift (força, duração) deve crescer com a intensidade do impacto, dentro de parâmetros configuráveis.
- **FR-013**: Durante o drift, o jogador deve manter controle parcial sobre esquerda/direita, reduzido por um fator configurável; o controle nunca deve ser totalmente retirado.
- **FR-014**: Encerrado o drift, o controle deve retornar gradualmente a 100%, a uma taxa configurável; o drift deve ter duração limitada.
- **FR-015**: O ciclo de estados do jogador na colisão deve seguir a sequência: normal → impacto → drift → recuperação → normal, sem outros estados.
- **FR-016**: Nenhuma colisão pode causar Game Over, direta ou indiretamente.

**Colisão 1-3: NPC atinge a traseira do jogador**

- **FR-017**: Quando um NPC atinge a traseira do jogador, a velocidade do NPC não deve ser reduzida pela colisão.
- **FR-018**: Nessa colisão, o NPC deve receber um deslocamento lateral temporário para o lado oposto ao drift aplicado ao jogador.
- **FR-019**: O deslocamento do NPC deve ser suficiente para viabilizar a ultrapassagem em pista livre — critério objetivo: ao fim do deslocamento, as hitboxes do jogador e do NPC não se intersectam mais e o NPC termina à frente do jogador no eixo do percurso; sua magnitude, a duração da ida e a duração do retorno à faixa devem ser configuráveis.
- **FR-020**: O deslocamento do NPC deve ser limitado pelos limites válidos da estrada na altura do NPC, inclusive durante transições de largura.
- **FR-021**: Concluída a ida, o NPC deve retornar à faixa que ocupava antes do deslocamento, dentro da duração de retorno configurada, e só então o deslocamento se encerra — nunca ficando deslocado lateralmente para sempre, sem drift permanente, perda de controle ou dano. Um NPC que permanece fora da faixa da sua velocidade passa a ser movido junto com o veículo de outra categoria, alterando as velocidades relativas do trânsito sem intenção de projeto.

**Limites da estrada**

- **FR-022**: Todo deslocamento provocado por colisão — drift do jogador e deslocamento do NPC — deve respeitar os limites válidos da estrada na altura do veículo, obtidos do sistema da estrada, sem assumir largura fixa.
- **FR-023**: A regra de FR-022 deve valer em pistas de 2 vias, de 4 vias e durante as transições entre elas.

**Intensidade do impacto**

- **FR-024**: A intensidade do impacto deve ser calculada a partir da velocidade relativa entre os dois veículos no momento do contato, não da velocidade máxima de cada categoria isoladamente.
- **FR-025**: Diferenças maiores de velocidade devem produzir perda de velocidade, força de drift e duração de drift maiores, conforme uma fórmula configurável.

**Cooldown**

- **FR-026**: Deve existir um cooldown configurável que impede que uma mesma colisão gere penalizações repetidas enquanto os veículos permanecerem sobrepostos.
- **FR-027**: O cooldown deve ser controlado por par jogador↔NPC, de modo que NPCs diferentes nunca sejam tratados como a mesma colisão.
- **FR-028**: Colisões ignoradas pelo cooldown não devem emitir evento nem aplicar consequência alguma.

**Evento de colisão e integrações futuras**

- **FR-029**: Toda colisão válida deve emitir um evento contendo, no mínimo: jogador, veículo NPC envolvido, tipo da colisão, velocidade de impacto, direção do drift e intensidade do impacto.
- **FR-030**: O sistema de colisão não deve modificar combustível, pontuação, dano visual ou qualquer outro sistema; ele apenas emite o evento, que specs futuras (ex.: combustível) poderão observar.
- **FR-031**: Colisões entre NPCs e colisões com elementos decorativos não devem existir nesta versão.

**Compatibilidade e arquitetura**

- **FR-032**: O sistema deve funcionar para todas as categorias de veículo de trânsito existentes (caminhão, esporte, passeio, utilitário) usando apenas dados fornecidos por cada veículo, sem depender de sprite ou nome de arquivo.
- **FR-033**: O sistema de colisão deve ser um componente separado do sistema de trânsito; a criação, a movimentação e a reciclagem dos NPCs permanecem responsabilidade do sistema de trânsito.
- **FR-034**: Nenhum sistema anterior (controle do jogador, estrada, ambientes, trânsito, decoração) pode ter seu comportamento alterado quando não há contato; ver SPEC-004 para os invariantes preservados.
- **FR-035**: Todas as constantes de ajuste usadas pela colisão e pelo drift — incluindo as listadas em "Parâmetros configuráveis" — devem ser configuráveis sem alteração de código, centralizadas na configuração do projeto, e nenhum valor desses conjuntos pode estar fixo na lógica.

**Bloqueio da aceleração pós-colisão (ajuste de 2026-10-05)**

- **FR-036**: Toda colisão válida deve desconsiderar a aceleração do jogador por uma janela de tempo configurável contada a partir do impacto: enquanto a janela estiver ativa, pressionar aceleração não aumenta a velocidade (prevalece a desaceleração natural); a frenagem permanece válida durante toda a janela; e, expirada a janela, a aceleração volta a aumentar a velocidade normalmente. Sem colisão, o estado é inerte e o comportamento é idêntico ao SPEC-001 (FR-034).

**Parâmetros configuráveis** (nomes de referência, adaptáveis à convenção do projeto):

- perda de velocidade mínima e máxima da colisão;
- força, duração, fator de controle e taxa de recuperação do drift;
- tempo de cooldown da colisão;
- margem neutra da posição relativa;
- magnitude, duração da ida e duração do retorno à faixa do deslocamento de ultrapassagem do NPC;
- dimensões das hitboxes do jogador e de cada categoria de NPC;
- duração da janela de desconsideração da aceleração pós-colisão (FR-036).

### Key Entities *(include if feature involves data)*

- **Colisão**: evento instantâneo entre jogador e um NPC. Atributos: par envolvido, tipo (1-1, 1-2 ou 1-3), velocidade de impacto, intensidade, direção do drift. Efêmera: existe no quadro da detecção e alimenta o evento de colisão.
- **Estado de Drift do Jogador**: condição temporária pós-colisão. Atributos: fase (impacto, drift, recuperação), direção, força restante, tempo decorrido, fator de controle vigente. Pertence exclusivamente ao jogador.
- **Hitbox**: área física retangular usada na detecção, configurável por veículo/categoria e independente do sprite. Atributos: largura e altura efetivas relativas ao centro do veículo.
- **Deslocamento de Ultrapassagem do NPC**: estado temporário do NPC na colisão 1-3. Atributos: fase (ida ou retorno), direção (oposta ao drift do jogador), magnitude, duração restante da fase, faixa de origem (x ocupado antes da colisão). Nunca altera a velocidade do NPC.
- **Configuração de Colisão e Drift**: conjunto de parâmetros de ajuste listados em FR-035, centralizado e legível pelos sistemas sem alteração de código.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das colisões válidas entre jogador e NPC são detectadas no quadro em que as hitboxes se intersectam, e nenhuma colisão é registrada sem interseção.
- **SC-002**: Em 100% dos cenários de aceitação das User Stories US1–US7 deste spec (referência oficial dos testes obrigatórios), a direção do drift aplicada ao jogador corresponde ao lado relativo dele em relação ao NPC.
- **SC-003**: Em 100% das colisões, a perda de velocidade do jogador fica dentro do intervalo configurado e a velocidade nunca fica abaixo de zero.
- **SC-004**: Em 100% do tempo de duração do drift, o jogador conserva pelo menos o fator de controle configurado (padrão de referência: 40%) e, ao fim da recuperação, o controle é exatamente 100%.
- **SC-005**: Com os veículos mantidos sobrepostos, uma única colisão gera no máximo uma penalização durante todo o período do cooldown configurado.
- **SC-006**: Em 100% das colisões do tipo "NPC atinge a traseira do jogador", a velocidade do NPC ao sair é igual à velocidade de entrada, e o NPC completa a ultrapassagem em pista livre.
- **SC-007**: Em 100% das colisões — em pista de 2 vias, de 4 vias e durante as transições — o jogador e o NPC permanecem dentro dos limites trafegáveis vigentes na altura de cada um após qualquer deslocamento.
- **SC-008**: 100% das colisões válidas emitem o evento de colisão com os seis dados mínimos de FR-029; colisões sob cooldown emitem zero eventos.
- **SC-009**: A troca do sprite de qualquer veículo por outro de dimensão diferente não altera nenhum resultado dos cenários de aceitação das User Stories US1–US7.
- **SC-010**: Com o sistema de colisão ativo e nenhum contato ocorrendo, todos os comportamentos dos SPECs 001 a 004 continuam aprovados na respectiva cobertura de testes (zero regressões).
- **SC-011**: Com colisões ocorrendo continuamente nos 4 ambientes, o jogo mantém a meta de 60 FPS e nunca cai abaixo do piso de 30 FPS.
- **SC-012**: 100% dos parâmetros listados na seção de parâmetros configuráveis podem ser alterados somente por configuração, com resultado observável sem alteração de código.
- **SC-013**: Em 100% das colisões, durante toda a janela configurada pós-impacto, manter a aceleração pressionada não aumenta a velocidade do jogador; a frenagem reduz a velocidade normalmente durante a janela; e, expirada a janela, a aceleração volta a aumentar a velocidade.
- **SC-014**: Em 100% das colisões tipo 1-3, decorridos a duração da ida mais a duração do retorno (ambas configuráveis), o NPC ocupa exatamente o x da faixa que ocupava antes da colisão (tolerância de 0,1 px) com o deslocamento inativo; nenhuma colisão deixa o NPC permanentemente fora da faixa da sua velocidade.

## Assumptions

- **Direção dentro da margem neutra**: quando a diferença lateral está dentro do limiar configurado, o drift é decidido para o lado com mais espaço trafegável disponível na altura do jogador; em empate absoluto, para a esquerda. A regra é determinística e documentada em FR-005.
- **Sobrepostos além do cooldown**: se dois veículos ainda estiverem sobrepostos quando o cooldown terminar, não há nova penalização enquanto não houver separação e novo contato — o cooldown protege o *impacto*, não o *veículo* para sempre.
- **Valores padrão de ajuste**: perda de velocidade, força e duração do drift, fator de controle de 40% e demais parâmetros terão padrões calibrados na implementação a partir da sensação arcade pedida; todos permanecem configuráveis (FR-035).
- **Hitboxes iniciais**: derivadas da área visual atual de cada categoria com margens laterais reduzidas, ajustáveis por configuração; a lógica nunca consulta o sprite (FR-008, SC-009).
- **Unidades**: os valores em km/h da descrição seguem a convenção de projeto do SPEC-004 (referência de design; a conversão para as unidades internas fica a cargo do plano).
- **Sem física de rotação ou capotamento**: o modelo arcade é exclusivamente translacional (longitudinal e lateral), conforme o escopo.
- **Dependências**: o sistema consome os dados já expostos pelo trânsito (identificação, posição, área ocupada — FR-025 do SPEC-004) como entrada, sem alterar as responsabilidades dele (FR-033).

## Out of Scope

Conforme a descrição da feature, não são implementados nesta spec: combustível e postos; dano visual; destruição de veículos; explosões; Game Over; vitória; pontuação; colisão NPC×NPC; física realista; rotação física; capotamento; tráfego em sentido contrário; IA avançada; dificuldade dinâmica; redução de velocidade do NPC como consequência de colisão. Cada um depende de especificação própria.
