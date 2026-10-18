# Feature Specification: Sistema de Colisão entre NPCs

**Feature Branch**: `006-npc-collision-system`

**Created**: 2026-10-07

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-006 — Sistema de Colisão entre NPCs" (colisões longitudinais e laterais entre veículos do trânsito na área ativa, previsão de colisão futura com janela de atividade, drift no veículo atingido, efeito dominó com limite de profundidade, cooldown por par, validação de spawn, reavaliação das condições quando a velocidade do jogador muda, e manutenção de todos os veículos dentro dos limites da pista — comportamento arcade, previsível e controlado).

## Clarifications

### Session 2026-10-07

- Q: Depois que o drift de um NPC atingido termina, o veículo deve voltar para a posição lateral que ocupava antes do impacto ou pode permanecer onde o deslocamento o deixou? → A: **Permanecer onde o drift terminou**, apenas respeitando os limites da pista — não há retorno obrigatório à faixa de origem. Consequência assumida: um veículo que termina fora do corredor da própria velocidade passa a interagir com o agrupamento lateral do SPEC-004, que usa a trajetória atual.
- Q: Quando um NPC é atingido por outro NPC, a velocidade dele pode cair temporariamente enquanto dura o impacto e o drift, ou deve permanecer exatamente a mesma o tempo todo? → A: **Nenhuma mudança de velocidade em nenhuma fase** — nem temporária nem permanente, para o atingido e para o causador; toda a resposta ao impacto é lateral (drift e deslocamento).
- Q: Quando a validação de spawn não encontra nenhuma posição nem faixa livre de conflito, o nascimento deve ser adiado para o quadro seguinte ou perdido até o próximo intervalo de spawn? → A: **Adiado para o quadro seguinte** e revalidado com as posições atualizadas — mesmo comportamento do adiamento já usado pelo SPEC-004 quando a faixa está ocupada; a reposição abaixo da densidade mínima continua garantida.
- Q: Se um NPC que já está em fase de drift for atingido por um terceiro veículo, o que deve acontecer com o drift dele? → A: **O novo impacto substitui o drift atual**, reiniciando direção, força e duração — um único deslocamento ativo por veículo (mesma regra da SPEC-005 para o jogador).
- Q: Colisões que ocorrem ao mesmo tempo mas sem relação entre si (veículos diferentes, sem elo formado por deslocamento) devem ser registradas na mesma cadeia ou em cadeias separadas? → A: **Cadeias separadas** — apenas o elo criado pelo deslocamento do NPC atingido encadeia impactos; colisões paralelas iniciam cadeias próprias.

### Session 2026-10-09

- Q: Quando NPCs de velocidades diferentes dividem a mesma trajetória, o limitador de espaçamento do trânsito deve ceder para que o veículo de trás encoste fisicamente no da frente? (US1) → A: **Sim — trânsito real**: entre velocidades diferentes na mesma trajetória o espaçamento mínimo cede durante o movimento até o contato físico das áreas; no nascimento o espaçamento mínimo continua valendo e pares de mesma velocidade permanecem em fila, sem aproximação.
- Q: A spec deve reescrever a premissa de que pares de velocidades diferentes dividem trajetória "raramente" e só "sobretudo após deslocamentos", já que a sonda mostrou o compartilhamento vindo do próprio trânsito (recuo para outra faixa no nascimento, nascimento adjacentes e convergência no estreitamento)? (US1/US7) → A: **Reescrever com nota de dívida**: o compartilhamento também surge do próprio trânsito, e os defeitos de nascimento/convergência da SPEC-004 ficam registrados como dívida conhecida, fora do escopo desta spec.
- Q: A spec deve cobrar por critério mensurável do caso natural — um par de velocidades diferentes que divide corredor no jogo real resolver em contato + drift dentro da área ativa — além dos cenários montados com posicionamento forçado da US1? (SC/US1) → A: **Cenário de aceitação da US1, sem novo SC** — o caso natural entra como sexto cenário de aceitação da US1.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Alcançar um NPC mais lento na mesma trajetória e desviá-lo (Priority: P1)

Um NPC mais rápido que está atrás de um mais lento, na mesma faixa de trajetória, aproxima-se progressivamente até que as áreas físicas dos dois se toquem. O jogo detecta o contato, classifica como colisão longitudinal, identifica o NPC mais rápido como causador e o mais lento como atingido, e aplica ao atingido um deslocamento lateral temporário (drift) numa direção calculada pela posição relativa dos dois veículos. O causador não sofre drift e não perde velocidade.

**Why this priority**: É o núcleo da spec — a regra "mais rápido atrás de mais lento pode colidir" com a resposta arcade (drift no atingido, causador intacto). Sem ela, os efeitos dominó, as bordas e a validação de spawn não têm sobre o que se apoiar. É o MVP.

**Independent Test**: Com dois NPCs na mesma trajetória, o mais rápido posicionado atrás do mais lento a uma distância curta, avançar até o contato e verificar a classificação "longitudinal", o drift no atingido, a direção do drift conforme o lado do impacto e a ausência de drift e de perda de velocidade no causador. Validável sem nenhuma outra história implementada.

**Acceptance Scenarios**:

1. **Given** um NPC esporte (120 km/h) atrás de um caminhão (90 km/h) na mesma trajetória e a distância curta, **When** as áreas físicas se intersectam, **Then** a colisão é detectada e classificada como longitudinal, o caminhão (atingido) sofre drift e o esporte (causador) não sofre drift nem perde velocidade.
2. **Given** o impacto ocorrendo pelo lado esquerdo do caminhão, **When** o drift é calculado, **Then** a direção do drift do caminhão é para a direita.
3. **Given** o impacto ocorrendo pelo lado direito do caminhão, **When** o drift é calculado, **Then** a direção do drift do caminhão é para a esquerda.
4. **Given** a diferença horizontal entre os dois veículos dentro da margem neutra configurável, **When** a direção do drift é decidida, **Then** o resultado é determinístico e estável, sem oscilar entre os lados.
5. **Given** qualquer colisão NPC×NPC, **When** ela termina, **Then** a velocidade dos dois envolvidos permanece exatamente a mesma de antes da colisão, sem variação em nenhuma fase.
6. **Given** um par de velocidades diferentes dividindo a mesma trajetória por efeito do próprio trânsito (nascimento adjacente, recuo de faixa ou convergência ao estreitar a pista), **When** o tempo estimado até o encontro cabe na janela de atividade, **Then** o veículo de trás encosta no da frente e o contato é resolvido com drift dentro da área ativa — o par não permanece simplesmente avançando junto sem se tocar enquanto o encontro cabe na janela.

---

### User Story 2 - Prever se a colisão vai acontecer antes do descarte de um dos veículos (Priority: P1)

O jogo avalia continuamente os pares de NPCs na mesma trajetória e calcula se um alcança o outro enquanto ambos ainda permanecem na área ativa. Um NPC mais rápido logo atrás de um mais lento gera previsão de colisão; o mesmo par com distância grande demais — de modo que o encontro só ocorreria depois que um deles já tivesse sido reciclado — não gera previsão. NPCs com a mesma velocidade, ou em trajetórias distintas, também não geram previsão.

**Why this priority**: É a "regra fundamental" da spec: diferença de velocidade sozinha não determina colisão. Sem a janela de atividade, o sistema produziria tanto colisões fantasma (falsos positivos) quanto encontros ignorados (falsos negativos), quebrando a previsibilidade arcade.

**Independent Test**: Montar o Cenário 1 (esporte atrás de caminhão, distância curta) e o Cenário 2 (mesmo par, distância grande, encontro só após o descarte) e verificar que apenas o primeiro resulta em previsão de colisão; repetir com par de mesma velocidade e com par em trajetórias diferentes, esperando nenhuma previsão nos dois últimos.

**Acceptance Scenarios**:

1. **Given** um NPC mais rápido atrás de um mais lento na mesma trajetória a distância curta, **When** o tempo estimado até o encontro é menor ou igual à janela de atividade conjunta, **Then** a colisão é considerada potencial e pode ocorrer.
2. **Given** o mesmo par com distância tão grande que o encontro ocorreria somente após a reciclagem de um dos veículos, **When** a previsão é calculada, **Then** nenhuma colisão futura é considerada dentro da área ativa.
3. **Given** dois NPCs com a mesma velocidade na mesma trajetória, **When** a diferença de velocidade é avaliada, **Then** não existe aproximação longitudinal por diferença de velocidade e nenhuma colisão é prevista por esse motivo.
4. **Given** dois NPCs em trajetórias distintas (projeções laterais sem sobreposição), **When** a previsão é calculada, **Then** nenhuma colisão é prevista entre eles, mesmo que um seja mais rápido que o outro.
5. **Given** a distância curta entre dois NPCs em que um alcança o outro dentro da área ativa, **When** a formação permanece por tempo suficiente, **Then** a colisão é detectada quando as áreas se intersectam — a previsão não é bloqueada por ter sido "segura" num instante anterior.

---

### User Story 3 - Sofrer contato lateral com outro NPC (Priority: P1)

Dois NPCs que ocupam trajetórias lateralmente sobrepostas colidem predominantemente pela lateral (por exemplo, um NPC deslocado por um drift invade a trajetória do vizinho). O jogo classifica o contato como lateral, aplica drift e deslocamento lateral ao NPC atingido com intensidade proporcional ao impacto e deixa o causador intacto.

**Why this priority**: É o segundo tipo de contato mais frequente entre NPCs e é o que dá vida ao efeito dominó (o NPC atingido deslocado atinge um terceiro). Compartilha a regra de direção do drift com a US1, mas exige classificação distinta.

**Independent Test**: Aproximar dois NPCs pela lateral, dos dois lados, e observar a classificação "lateral", o drift no atingido na direção correta e a ausência de drift no causador.

**Acceptance Scenarios**:

1. **Given** dois NPCs lado a lado na mesma altura, **When** as áreas se intersectam predominantemente pela lateral, **Then** o contato é classificado como lateral.
2. **Given** o NPC da esquerda recebendo o impacto, **When** o drift é aplicado, **Then** o atingido desloca-se para a esquerda e o causador permanece sem drift.
3. **Given** a diferença de velocidade relativa entre os dois no instante do contato, **When** a intensidade é calculada, **Then** intensidades maiores produzem deslocamentos maiores, dentro de intervalos configuráveis.
4. **Given** uma mesma faixa ocupada por dois veículos colados com diferença lateral dentro da margem neutra, **When** a direção é decidida, **Then** o resultado é determinístico, sem oscilação.

---

### User Story 4 - Não deixar nenhum NPC sair da pista durante um impacto (Priority: P1)

Numa pista estreita (2 vias) ou durante uma transição de largura, um NPC atingido está encostado numa das bordas. O drift calculado apontaria para fora da pista. O jogo verifica o espaço disponível, tenta a direção oposta e, se nenhum dos lados comportar o deslocamento, transfere o deslocamento para o NPC causador. Em nenhuma situação qualquer veículo sai dos limites válidos da estrada.

**Why this priority**: "Nenhum NPC pode sair dos limites válidos da pista" é um invariante do jogo (constitution, §Pista e §Veículo do Jogador) e condição de aceitação explícita. Sem ele, o drift quebraria a jogabilidade em pistas estreitas.

**Independent Test**: Posicionar o NPC atingido colado à borda direita num trecho de 2 vias, provocar um impacto cujo drift normal seria "direita", e verificar que o drift ocorre à esquerda; repetir sem espaço em nenhum dos lados e verificar que o deslocamento é aplicado ao causador; conferir, quadro a quadro, que nenhum veículo ultrapassa os limites.

**Acceptance Scenarios**:

1. **Given** um NPC atingido próximo da borda direita, **When** a direção normal do drift aponta para fora da pista, **Then** o sistema tenta a direção oposta e aplica o drift nela, desde que haja espaço.
2. **Given** o NPC atingido colado à borda sem espaço em nenhum lado, **When** nenhum dos lados comporta o deslocamento, **Then** o deslocamento é transferido ao NPC causador, também limitado pelos limites da pista.
3. **Given** qualquer colisão em qualquer ponto da pista, **When** o deslocamento é aplicado, **Then** nenhum dos envolvidos ultrapassa os limites válidos da estrada na altura do veículo.
4. **Given** a mesma situação durante a transição de 2 para 4 vias e de 4 para 2 vias, **When** a largura da pista muda no meio do deslocamento, **Then** os limites vigentes são aplicados continuamente e nenhum veículo sai da área trafegável.
5. **Given** uma pista com 2 vias e outra com 4 vias, **When** o sistema calcula espaço lateral, **Then** ele usa os limites correntes do sistema de estrada, sem assumir largura fixa.

---

### User Story 5 - Produzir efeito dominó controlado, sem loops nem impactos repetidos (Priority: P1)

Uma colisão desloca um NPC, que atinge um terceiro, que por sua vez atinge um quarto. A reação em cadeia acontece, mas é controlada: existe uma profundidade máxima, a cadeia expira com o tempo, nenhum veículo é processado duas vezes na mesma cadeia (nada de A → B → A → B) e um mesmo par de veículos não repete impacto enquanto estiver em cooldown — enquanto isso, outros pares da mesma cadeia podem continuar colidindo.

**Why this priority**: O efeito dominó é o comportamento mais característico pedido, mas sem os controles ele vira caos (loops infinitos, impactos vibrátil). Os controles são tão obrigatórios quanto o próprio efeito.

**Independent Test**: Dispor três NPCs em fila na mesma trajetória, provocar o impacto do primeiro no segundo e observar a cadeia A → B → C; aumentar para quatro e verificar que a profundidade máxima é respeitada; provocar um confronto que devolveria o impacto a A e verificar que B já processado não gera novo evento; colidir A ↔ B e, ainda durante o cooldown, provocar B ↔ C e verificar que apenas o segundo ocorre.

**Acceptance Scenarios**:

1. **Given** três NPCs em fila na mesma trajetória, **When** o primeiro atinge o segundo, **Then** o segundo atinge o terceiro e uma cadeia de profundidade 2 é registrada.
2. **Given** uma cadeia atingindo a profundidade máxima configurada, **When** um novo impacto seria o próximo elo, **Then** ele não é processado e a cadeia não avança.
3. **Given** um par A ↔ B já em cooldown, **When** B é atingido por C, **Then** a colisão B ↔ C ocorre normalmente enquanto A ↔ B permanece bloqueado.
4. **Given** um veículo já processado na cadeia atual, **When** um impacto o levaria a ser processado de novo, **Then** o impacto é descartado e nenhum loop é gerado.
5. **Given** uma cadeia em andamento, **When** o tempo da cadeia expira, **Then** nenhum elo adicional é processado.
6. **Given** um mesmo par separando-se e voltando a se tocar, **When** o cooldown do par ainda está ativo, **Then** nenhum novo evento nem consequência é gerado; após a expiração, um novo contato pode gerar nova colisão.
7. **Given** um NPC em fase de drift atingido por um terceiro veículo de outro par, **When** o novo impacto é processado, **Then** o drift atual é substituído pelo novo (direção, força e duração reiniciadas) e o evento do novo par é emitido normalmente.
8. **Given** duas colisões independentes ocorrendo dentro do tempo de expiração de uma cadeia ativa, **When** ambas são registradas, **Then** cada uma recebe identificador de cadeia e profundidade próprios — nenhuma herda a cadeia alheia por proximidade no tempo.

---

### User Story 6 - Recuperar o NPC atingido gradualmente e informar outros sistemas (Priority: P2)

Após ser atingido, o NPC percorre as fases normal → colisão → drift → recuperação → normal, com trajetória temporariamente alterada, deslocamento limitado e retorno gradual ao fluxo do trânsito, sem qualquer mudança de velocidade. Cada colisão válida emite um evento com os dados do impacto, permitindo que efeitos visuais, áudio, partículas, pontuação ou telemetria futuros observem o ocorrido sem alterar o sistema de colisão.

**Why this priority**: É o acabamento do comportamento (temporariedade, recuperação) e o ponto de integração para specs futuras. Importante, mas só faz sentido depois das colisões existirem.

**Independent Test**: Aplicar uma colisão a um NPC e acompanhar a sequência de fases até o retorno ao normal, conferindo que a velocidade não mudou em nenhuma delas; assinar o evento de colisão e verificar que ele traz os sete dados pedidos.

**Acceptance Scenarios**:

1. **Given** um NPC atingido, **When** o tempo avança, **Then** ele percorre as fases normal → colisão → drift → recuperação → normal, sem outros estados.
2. **Given** um NPC em fase de drift, **When** a recuperação progride, **Then** o controle da trajetória retorna gradualmente ao fluxo normal até o término configurado.
3. **Given** qualquer cadeia de colisões envolvendo um NPC, **When** tudo termina, **Then** a velocidade do NPC é idêntica à de antes do primeiro impacto, sem variação em nenhuma fase.
4. **Given** uma colisão NPC×NPC válida, **When** ela ocorre, **Then** um único evento é emitido contendo: veículo causador, veículo atingido, tipo da colisão (longitudinal/lateral), intensidade do impacto, direção do drift, identificador da cadeia e profundidade atual da cadeia.
5. **Given** o evento emitido, **When** nenhum outro sistema o observa, **Then** nada muda — o evento é somente informativo nesta versão.
6. **Given** um NPC cujo drift terminou fora da lateral que ocupava antes do impacto, **When** a recuperação termina, **Then** ele continua na posição alcançada, sem retorno obrigatório à origem, sempre dentro dos limites da pista.

---

### User Story 7 - Não nascer em cima de um conflito (Priority: P2)

Quando um novo NPC entra na pista, o gerenciador de trânsito o valida contra os NPCs já ativos: mesma faixa, velocidade relativa, distância longitudinal, tempo estimado até a colisão, janela de atividade e distância mínima de segurança. Se a posição geraria uma colisão imediata não desejada, ele procura outra posição, depois outra faixa e, na impossibilidade, adia o nascimento para o quadro seguinte, revalidando com as posições atualizadas — o nascimento nunca é perdido até o próximo intervalo. Conflitos que só ocorreriam depois do descarte não bloqueiam o nascimento.

**Why this priority**: A validação de spawn evita situações impossíveis logo na entrada, mas depende da regra de previsão da US2 — por isso P2.

**Independent Test**: Programar o nascimento de um NPC rápido logo atrás de um lento na mesma faixa e observar a recusa/reposicionamento; programar um nascimento com conflito futuro dentro da área ativa e observar a identificação; programar um com encontro somente após o descarte e observar que o nascimento é aceito.

**Acceptance Scenarios**:

1. **Given** um NPC rápido prestes a nascer atrás de um lento na mesma faixa a distância insuficiente, **When** a validação é executada, **Then** o sistema tenta outra posição válida, depois outra faixa válida e, na impossibilidade no quadro, adia o nascimento para o quadro seguinte, revalidando com as posições atualizadas — nunca descartando o nascimento até o próximo intervalo de spawn.
2. **Given** um nascimento que colidiria imediatamente com um NPC já ativo, **When** a validação é executada, **Then** a colisão imediata não intencional é evitada — nenhum par nasce sobreposto.
3. **Given** um nascimento cujo encontro com um NPC ativo ocorreria dentro da área ativa, **When** a previsão é calculada, **Then** a situação de colisão futura é identificada e tratada pela mesma regra da janela.
4. **Given** um nascimento cujo encontro só ocorreria depois que um dos veículos já tivesse sido reciclado, **When** a previsão é calculada, **Then** a situação **não** é considerada colisão ativa e não bloqueia o nascimento.
5. **Given** o nascimento validado, **When** ele ocorre, **Then** o limite máximo de NPCs ativos e o espaçamento mínimo vigente do trânsito continuam respeitados.

---

### User Story 8 - Reavaliar as colisões quando o jogador muda de velocidade (Priority: P2)

O jogador acelera com vários NPCs na tela; a formação parece segura. Quando ele solta o aceleração ou freia, a progressão relativa dos veículos na tela muda e os NPCs permanecem juntos por tempo diferente na área ativa. O sistema reavalia as condições de colisão e passa a enxergar aproximações que antes não existiam — sem inventar colisões onde a regra da janela não é satisfeita.

**Why this priority**: Garante que a detecção acompanhe a condução real em vez de congelar no estado do nascimento. Depende da janela da US2, por isso P2.

**Independent Test**: Montar uma formação segura (C 90, E 120, U 90, P 100, jogador a 125), fazer o jogador frear e verificar que a reavaliação ocorre e que uma aproximação que passou a caber na janela é detectada; repetir sem mudança de velocidade relevante e verificar que nenhuma colisão adicional aparece.

**Acceptance Scenarios**:

1. **Given** o jogador acelerando com 5 NPCs ativos, **When** ele mantém a velocidade, **Then** o sistema continua avaliando os pares sem produzir colisões artificiais.
2. **Given** o jogador deixando de acelerar, **When** a velocidade dele diminui, **Then** a progressão relativa dos NPCs na tela é atualizada e uma reavaliação é disparada.
3. **Given** o jogador freando com múltiplos NPCs ativos, **When** a frenagem altera a dinâmica da área ativa, **Then** as condições de colisão são recalculadas.
4. **Given** uma formação inicialmente segura, **When** a mudança de velocidade do jogador prolonga a permanência conjunta na área ativa, **Then** uma nova condição de colisão é detectada mesmo que inexistente alguns instantes antes.
5. **Given** qualquer reavaliação, **When** a regra da janela (distância, diferença de velocidade, janela de atividade) não é satisfeita, **Then** nenhuma colisão é gerada.
6. **Given** outras mudanças relevantes (velocidade de um NPC, mudança de faixa, deslocamento por colisão, entrada ou reciclagem de NPC, mudança de configuração da pista), **When** qualquer uma ocorre, **Then** o sistema pode reavaliar os pares afetados.

---

### User Story 9 - Preservar o jogo todo: jogador, 5 NPCs e transições de pista (Priority: P1)

O novo sistema convive com o sistema de colisão do jogador sem duplicar responsabilidades: um NPC deslocado por uma colisão NPC×NPC que depois atinge o jogador é tratado pelo sistema da SPEC-005, com exatamente um evento. A presença do jogador entre dois NPCs não bloqueia a previsão entre eles. O sistema funciona com até 5 NPCs ativos no ambiente de gelo e durante toda a transição 2 vias → 4 vias → 2 vias, sem regressão das features anteriores.

**Why this priority**: Uma feature que quebra o jogo existente ou o sistema de colisão do jogador não pode ser entregue; é a condição de aceitação do pacote inteiro.

**Independent Test**: Rodar uma partida com 5 NPCs no ambiente de gelo, incluindo uma transição completa de vias e ao menos uma colisão NPC×NPC que resulte em contato com o jogador; conferir o evento único do SPEC-005, os limites da pista e a ausência de regressões nas suítes das SPEC-001 a SPEC-005.

**Acceptance Scenarios**:

1. **Given** o ambiente de gelo com o teto configurado de 5 NPCs, **When** a partida roda com o jogador acelerando, **Then** até 5 NPCs permanecem ativos simultaneamente e todas as combinações relevantes de aproximação são avaliadas.
2. **Given** um NPC deslocado por uma colisão NPC×NPC, **When** ele atinge o jogador, **Then** a colisão é encaminhada ao sistema da SPEC-005 e exatamente um evento do jogador é emitido, sem lógica duplicada.
3. **Given** o jogador posicionado entre dois NPCs, **When** a previsão entre esses dois é calculada, **Then** a presença do jogador não bloqueia nem altera a avaliação.
4. **Given** uma formação de NPCs em 2 vias, **When** a pista transiciona para 4 vias, **Then** as avaliações continuam corretas, os deslocamentos seguem os limites vigentes e nenhum veículo sai da área trafegável.
5. **Given** a mesma formação em 4 vias, **When** a pista retorna para 2 vias, **Then** o comportamento é o mesmo, sem limites fixos de largura em nenhuma regra.
6. **Given** o sistema de colisão jogador×NPC da SPEC-005, **When** não há contato do jogador com NPCs, **Then** nenhum comportamento anterior muda (SPEC-001 a SPEC-005 preservados).

---

### Edge Cases

- NPCs nascem em corredores laterais reservados por velocidade (SPEC-004), mas pares de velocidades diferentes podem dividir a mesma trajetória já pelo próprio funcionamento do trânsito: recuo para outra faixa no nascimento e nascimentos adjacentes (folga lateral nula) que convergem para a mesma faixa ao estreitar a pista — além dos deslocamentos (ultrapassagem do SPEC-005, drift, transição de largura). A avaliação usa a trajetória **atual** de cada veículo, não a do nascimento.
- NPC deslocado por um drift invade a trajetória de um terceiro veículo no mesmo quadro em que a cadeia avança.
- Três ou mais NPCs sobrepostos simultaneamente: a ordem de processamento dos pares precisa ser determinística.
- Um dos NPCs é reciclado no mesmo quadro em que a previsão seria registrada.
- Par cujo cooldown expira enquanto os dois ainda estão sobrepostos.
- NPC atingido novamente durante a sua própria fase de drift: o novo impacto substitui o drift em curso (direção, força e duração reiniciadas pela nova classificação) e o par envolvido segue normalmente as regras de cooldown e de cadeia.
- Duas colisões independentes acontecendo enquanto uma cadeia ainda está dentro do seu tempo de expiração: cada uma inicia a sua própria cadeia — o identificador só é herdado pelo impacto causado pelo deslocamento do NPC atingido.
- Colisão que ocorre exatamente durante a transição de 2 para 4 vias, com os limites em movimento.
- Pista de 2 vias com dois veículos largos lado a lado: nenhum dos lados comporta o deslocamento.
- Jogador completamente parado (estrada sem scroll): NPCs mais rápidos sobem na tela e a janela de atividade encurta.
- Cadeia maior que o número de NPCs ativos disponíveis (5) — a profundidade máxima é o limite real.
- Spawn no mesmo quadro em que outro NPC sai de cena: a validação deve usar a lista já atualizada.
- Dois NPCs da mesma categoria na mesma trajetória, encostados (espaçamento mínimo) e com velocidades idênticas: nenhuma aproximação, nenhum evento.
- Diferença de velocidade menor que o limiar configurável de velocidade relativa mínima: a aproximação não é considerada relevante.
- NPC que termina o drift fora do corredor lateral reservado para a sua velocidade: ele permanece nessa trajetória até nova mudança, e o agrupamento lateral do SPEC-004 passa a considerá-lo na trajetória atual (sem retorno automático à origem).

## Requirements *(mandatory)*

### Functional Requirements

**Previsão de colisão e janela de atividade**

- **FR-001**: O sistema deve avaliar continuamente os pares de NPCs ativos cujas trajetórias se sobreponham lateralmente, calculando se um pode alcançar o outro antes de qualquer um dos dois ser descartado.
- **FR-002**: Para cada par, quando a diferença de velocidade (traseiro menos dianteiro) for menor ou igual a zero, deve resultar ausência de aproximação longitudinal por diferença de velocidade, sem previsão de colisão por esse motivo.
- **FR-003**: Havendo diferença de velocidade positiva acima do limiar configurável, o tempo até a colisão deve ser obtido da distância longitudinal dividida pela diferença de velocidade; a colisão somente é considerada potencial quando esse tempo for menor ou igual à janela de atividade conjunta.
- **FR-004**: A janela de atividade conjunta deve considerar: limites da área visível, margem de segurança, distância até o descarte/reciclagem de cada um dos dois veículos, a velocidade de cada um, o movimento relativo entre eles e o estado atual da pista (largura e configuração de vias vigentes).
- **FR-005**: A janela deve evitar simultaneamente o falso positivo (prever colisão que ocorreria somente depois de um dos veículos já ter sido removido) e o falso negativo (ignorar colisão que ocorrerá com os dois ainda ativos).
- **FR-006**: Pares em trajetórias distintas — projeções laterais sem sobreposição — não devem gerar previsão nem colisão, mesmo que haja diferença de velocidade.
- **FR-007**: Um NPC mais rápido atrás de um mais lento deve ser tratado como **possibilidade** de colisão, nunca como obrigatoriedade: a confirmação depende sempre da distância e da janela de atividade.
- **FR-008**: As condições de colisão devem poder ser reavaliadas sob demanda e por atualização periódica configurável, sem exigir que todos os pares sejam avaliados a cada quadro; a avaliação deve poder ser limitada aos pares próximos, na mesma trajetória, com potencial de aproximação, dentro da área de colisão ou envolvidos em eventos de mudança relevante.
- **FR-009**: A presença do jogador entre dois NPCs, ou a sua proximidade, não deve ser usada como bloqueio automático da previsão de colisão entre eles; a avaliação considera apenas posição, velocidade, trajetória, distância e área ativa.

**Detecção e classificação do contato**

- **FR-010**: O contato real entre dois NPCs ativos deve ser detectado pela interseção das suas áreas físicas, configuráveis por categoria e independentes dos sprites.
- **FR-011**: Toda colisão detectada deve ser classificada em exatamente um de dois tipos — longitudinal ou lateral —, com base na geometria do contato no instante do impacto, e não numa direção fixa predefinida.
- **FR-012**: A intensidade do impacto deve ser calculada a partir da velocidade relativa entre os dois veículos no momento do contato, normalizada dentro de um intervalo configurável, de modo que diferenças maiores de velocidade produzam impactos mais fortes.
- **FR-013**: Em toda colisão devem ser identificados o causador e o atingido: numa colisão longitudinal, quem alcança é o causador; numa lateral, quem fecha a trajetória do outro é o causador; empates devem ser resolvidos de forma determinística e estável.

**Drift, deslocamento e limites da pista**

- **FR-014**: Todo NPC atingido deve receber um deslocamento lateral temporário (drift) cuja intensidade é proporcional à intensidade do impacto, dentro de parâmetros configuráveis. Cada veículo mantém um único drift ativo: um novo impacto (de outro par, não bloqueado pelo cooldown nem pela cadeia) **substitui** o drift em curso, reiniciando direção, força e duração pela nova classificação.
- **FR-015**: A direção do drift deve ser derivada da posição relativa entre o atingido e o causador, com uma tolerância lateral configurável: impacto pelo lado esquerdo resulta em drift para a direita, impacto pelo lado direito resulta em drift para a esquerda. A decisão deve considerar a trajetória e o sentido do movimento, nunca apenas a posição absoluta do sprite, e deve ser determinística dentro da tolerância.
- **FR-016**: O NPC causador não deve sofrer drift automaticamente nem perder velocidade por ter causado a colisão.
- **FR-017**: A velocidade de um NPC não pode ser alterada por nenhuma colisão NPC×NPC — nem temporariamente, nem permanentemente, em nenhuma das fases (colisão, drift ou recuperação) e nem por nenhuma cadeia de colisões. A resposta ao impacto é exclusivamente lateral; as velocidades dos dois envolvidos permanecem idênticas às de antes do impacto durante todo o processo.
- **FR-018**: Nenhum NPC pode sair dos limites válidos da pista: todo deslocamento provocado por colisão deve ser limitado pelos limites vigentes na altura do veículo, obtidos dinamicamente do sistema de estrada, sem largura fixa.
- **FR-019**: Quando o NPC atingido estiver próximo da borda (dentro da margem de borda configurável), o sistema deve: calcular a direção normal do drift; verificar se há espaço nessa direção; aplicar o drift se houver; caso contrário, tentar o lado oposto; se nenhum lado comportar o deslocamento, transferi-lo ao NPC causador, que também permanece limitado pelos limites da pista.
- **FR-020**: O deslocamento lateral de cada veículo durante um impacto deve ser limitado por um parâmetro de limite de deslocamento configurável.

**Estado do NPC após a colisão**

- **FR-021**: O estado de um NPC envolvido em colisão deve seguir a sequência normal → colisão → drift → recuperação → normal, sem outros estados.
- **FR-022**: Durante o drift, o controle de trajetória do NPC deve ser temporariamente alterado, o deslocamento lateral deve permanecer limitado, o veículo deve permanecer dentro da pista e o comportamento deve retornar gradualmente ao fluxo normal. Encerrada a recuperação, o NPC mantém a posição lateral alcançada pelo deslocamento — sem retorno obrigatório à faixa de origem —, permanecendo sujeito apenas aos limites da pista e à trajetória atual considerada pelo agrupamento lateral do SPEC-004.
- **FR-023**: O drift deve ser temporário, com duração e taxa de recuperação configuráveis; nenhum drift, dano, destruição ou perda de controle permanente pode resultar de uma colisão.

**Cadeia de colisões, prevenção de loops e cooldown**

- **FR-024**: Uma colisão deve poder iniciar uma reação em cadeia em que o NPC atingido desloca-se e atinge um terceiro veículo, e assim por diante. Apenas esse elo encadeia impactos: colisões paralelas sem relação entre si (veículos diferentes, sem o deslocamento de um NPC atingido como causa) iniciam cadeias próprias, mesmo que ocorram dentro do tempo de expiração de outra cadeia, com identificador e profundidade independentes.
- **FR-025**: A cadeia deve ser controlada por identificador da cadeia, profundidade máxima configurável, tempo de expiração da cadeia configurável e registro dos veículos já processados na cadeia atual: um veículo não pode ser processado duas vezes na mesma cadeia, e sequências de ida e volta entre o mesmo par devem ser bloqueadas.
- **FR-026**: O cooldown deve ser controlado por **par** de veículos, de modo que o par A ↔ B permaneça em cooldown enquanto o par B ↔ C ainda pode gerar uma nova colisão; durante o cooldown do par nenhum novo evento nem consequência deve ser aplicado, e um novo impacto do par somente pode ocorrer após a expiração do cooldown e a separação dos veículos.
- **FR-027**: Colisões bloqueadas pelo cooldown ou pela regra de cadeia não devem emitir evento nem aplicar consequência alguma.

**Validação de spawn**

- **FR-028**: Ao inserir um novo NPC, o gerenciador de trânsito deve validá-lo contra os NPCs atualmente ativos, considerando: mesma faixa/trajetória, compatibilidade de trajetória, velocidade relativa, distância longitudinal, tempo estimado até a colisão, janela de atividade e distância mínima de segurança de spawn.
- **FR-029**: Se o novo NPC gerar uma colisão imediata não desejada, o sistema deve: procurar outra posição válida; depois procurar outra faixa válida; e, na ausência de opção, **adiar o nascimento para o quadro seguinte** e revalidá-lo com as posições atualizadas. O nascimento nunca é descartado até o próximo intervalo de spawn por falta de opção no quadro, de modo que a reposição imediata abaixo da densidade mínima exigida pelo SPEC-004 permanece garantida.
- **FR-030**: Conflitos futuros devem ser avaliados pela mesma regra da janela de atividade: o encontro que ocorrer dentro da área ativa é identificado; o encontro que só ocorreria após o descarte de um dos veículos não é considerado colisão ativa.
- **FR-031**: O sistema de geração não deve criar situação impossível ou claramente indesejada em razão da lógica de spawn, e nenhum NPC deve nascer sobreposto a outro.

**Velocidade do jogador e reavaliação dinâmica**

- **FR-032**: O sistema deve operar sobre a progressão relativa existente entre os NPCs e a tela, de modo que a variação da velocidade do jogador (acelerar, manter, deixar de acelerar, desacelerar, frear) seja refletida no cálculo da janela de atividade e na permanência dos veículos na área ativa.
- **FR-033**: Mudanças relevantes na dinâmica da área ativa devem poder disparar reavaliação das condições de colisão: mudança significativa da velocidade do jogador, frenagem, desaceleração, alteração de velocidade de um NPC, mudança de faixa ou posição de um NPC, deslocamento causado por colisão, entrada de novo NPC, saída ou reciclagem de NPC e mudança na configuração da pista.
- **FR-034**: Uma formação inicialmente segura deve poder se tornar perigosa: uma condição de colisão que não existia anteriormente deve ser detectada após uma mudança relevante, e a ausência de condição em instantes anteriores não pode servir de bloqueio.
- **FR-035**: A reavaliação não pode produzir colisões artificiais: nenhuma colisão pode ser registrada sem que a regra da janela de atividade (FR-002, FR-003, FR-004) seja satisfeita no momento da avaliação.

**Responsabilidades, integração e escopo**

- **FR-036**: A detecção e a resolução de colisões NPC×NPC devem caber a um componente próprio, separado do sistema de trânsito (spawn, movimento, reciclagem, descarte) e do sistema de colisão jogador×NPC, sem duplicação de responsabilidades.
- **FR-037**: O sistema de colisão definido pela SPEC-005 permanece responsável exclusivamente pela colisão jogador × NPC; esta spec não duplica nem altera essa lógica.
- **FR-038**: Se um NPC deslocado por uma colisão NPC×NPC atingir o jogador em seguida, a colisão deve ser encaminhada ao sistema da SPEC-005, com exatamente um evento por contato válido.
- **FR-039**: Cada veículo de trânsito deve expor o estado individual necessário (posição, velocidade, faixa/trajetória, estado de drift, estado de recuperação e área física), sem detectar nem resolver colisões por conta própria.
- **FR-040**: O sistema de estrada deve fornecer os limites laterais, a largura e a configuração atuais; o sistema de colisão não altera a geometria da pista e não pode assumir largura fixa, devendo funcionar em 2 vias, em 4 vias e durante as transições entre elas.
- **FR-041**: Toda colisão NPC×NPC válida deve emitir um único evento contendo, no mínimo: veículo causador, veículo atingido, tipo da colisão, intensidade do impacto, direção do drift, identificador da cadeia e profundidade atual da cadeia. O evento é somente informativo: o sistema não modifica combustível, pontuação, dano ou qualquer outro sistema.
- **FR-042**: O sistema deve respeitar o teto configurável de NPCs ativos por ambiente/dificuldade — no ambiente de gelo, `max_active_npcs = 5` —, funcionando corretamente com até 5 NPCs simultâneos e mantendo o valor configurável para futuros níveis de dificuldade.
- **FR-043**: O comportamento deve ser arcade, previsível e controlado: sem física veicular realista, sem capotamento, sem rotação física dos veículos, sem frenagem inteligente e sem decisão estratégica dos NPCs.
- **FR-044**: Todos os parâmetros devem ser configuráveis sem alteração de código, centralizados na configuração do projeto (lista na seção seguinte), e nenhum deles pode estar fixo na lógica.
- **FR-045**: A avaliação deve ser limitada a pares relevantes e orientada a eventos mais atualização periódica, de modo que o jogo mantenha 60 quadros por segundo como meta e 30 como piso aceitável, com o jogador e até 5 NPCs ativos.
- **FR-046**: Entre NPCs de velocidades diferentes na mesma trajetória, o espaçamento mínimo de trânsito do SPEC-004 não impede a aproximação longitudinal durante o movimento: o veículo de trás pode fechar até que as áreas físicas dos dois se toquem, momento em que valem as regras de detecção e resposta desta spec. O espaçamento mínimo mantém vigência em dois casos: (a) no nascimento de qualquer NPC, conforme a validação de spawn (FR-028 a FR-031); e (b) entre NPCs de mesma velocidade na mesma trajetória, que permanecem em fila, sem aproximação por diferença de velocidade (FR-002).

**Parâmetros configuráveis** (nomes de referência, adaptáveis à convenção do projeto):

- `npc_collision_cooldown` — duração do cooldown por par de veículos;
- `npc_drift_force`, `npc_drift_duration`, `npc_drift_recovery_rate` — intensidade, duração e recuperação do drift do NPC atingido;
- `npc_relative_position_threshold` — tolerância lateral da margem neutra na direção do drift;
- `npc_border_margin` — margem que define "próximo da borda";
- `npc_max_chain_depth`, `npc_chain_timeout` — profundidade máxima e tempo de expiração da cadeia;
- `npc_displacement_limit` — limite do deslocamento lateral por impacto;
- `npc_spawn_safety_distance` — distância mínima de segurança na validação de spawn;
- `npc_collision_prediction_horizon` — horizonte máximo de previsão de colisão;
- `npc_min_relative_speed` — diferença mínima de velocidade para considerar aproximação;
- `npc_active_area_margin` — margem da área ativa usada no cálculo da janela;
- `npc_max_active` — teto de NPCs ativos (espelha o teto por nível de dificuldade);
- frequência de reavaliação periódica e o limiar de "mudança relevante" da velocidade do jogador que dispara reavaliação.

### Key Entities *(include if feature involves data)*

- **Par Candidato a Colisão**: relação entre dois NPCs ativos na mesma trajetória. Atributos: os dois veículos, distância longitudinal, diferença de velocidade, tempo estimado até a colisão, janela de atividade conjunta e veredito (potencial ou não). É a unidade de previsão e de reavaliação.
- **Colisão NPC×NPC**: evento instantâneo de contato entre dois NPCs. Atributos: causador, atingido, tipo (longitudinal ou lateral), intensidade, direção do drift, cadeia à qual pertence e profundidade. Efêmera: existe no quadro da detecção.
- **Cadeia de Colisão**: sequência de impactos iniciada por um primeiro contato. Atributos: identificador, profundidade atual, profundidade máxima, tempo restante e conjunto de veículos já processados.
- **Estado de Drift do NPC**: condição temporária pós-colisão de um veículo. Atributos: fase (normal, colisão, drift, recuperação), direção, intensidade, tempo restante da fase e deslocamento lateral atual. Nunca altera a velocidade do veículo, em nenhuma fase.
- **Cooldown por Par**: bloqueio temporário entre dois veículos específicos. Atributos: identidade do par e tempo restante. Isolado por par, de modo que outros pares continuem livres.
- **Evento de Colisão NPC×NPC**: registro informativo do impacto com os sete campos exigidos por FR-041; destinado a integrar efeitos visuais, áudio, partículas, pontuação, telemetria e dificuldade no futuro.
- **Configuração de Colisão NPC×NPC**: conjunto centralizado dos parâmetros listados em FR-044, legível pelos sistemas sem alteração de código.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cenário 1 (NPC rápido logo atrás de NPC lento, mesma trajetória) resulta em previsão de colisão em 100% das execuções do cenário; Cenário 2 (mesmo par a distância tão grande que o encontro ocorreria após o descarte) resulta em 0 previsões.
- **SC-002**: Em 100% das execuções, pares com velocidades iguais na mesma trajetória produzem 0 aproximações longitudinais por diferença de velocidade.
- **SC-003**: Em 100% das execuções, pares em trajetórias distintas produzem 0 previsões e 0 colisões entre si.
- **SC-004**: Em 100% das colisões longitudinais detectadas, o NPC atingido recebe drift e o causador não recebe drift nem perde velocidade.
- **SC-005**: Em 100% dos impactos, a direção do drift é a oposta ao lado pelo qual o impacto ocorreu; dentro da margem neutra configurável, 100% das decisões são determinísticas (mesmo resultado para a mesma configuração), sem oscilação entre os lados.
- **SC-006**: 0 NPCs ultrapassam os limites válidos da pista em qualquer quadro, verificado em partidas contínuas de 10 minutos em pistas de 2 vias, de 4 vias e durante as transições entre elas.
- **SC-007**: Em 100% dos impactos junto à borda: quando há espaço no lado oposto, o drift é aplicado nele; quando não há espaço em nenhum lado, o deslocamento é aplicado ao causador; em nenhuma hipótese algum veículo sai da pista.
- **SC-008**: O efeito dominó A → B → C ocorre em 100% dos ensaios com três veículos em fila; a profundidade máxima configurada é respeitada em 100% das cadeias; 0 veículos são processados duas vezes na mesma cadeia (0 loops); e colisões paralelas sem elo entre si recebem identificador e profundidade de cadeia próprios em 100% dos casos.
- **SC-009**: Com o par A ↔ B em cooldown, 0 novas colisões entre A e B ocorrem durante a janela de cooldown, enquanto 100% dos ensaios com B ↔ C no mesmo intervalo produzem a colisão do par B ↔ C.
- **SC-010**: Em 100% dos nascimentos: 0 NPCs criados sobrepostos ou em conflito imediato não desejado; 100% dos conflitos que ocorreriam dentro da área ativa são identificados; 0 dos conflitos que ocorreriam somente após o descarte são considerados ativos; e quando não existe opção livre no quadro o nascimento é adiado e revalidado, com 0 nascimentos descartados até o próximo intervalo de spawn.
- **SC-011**: Com o teto de 5 NPCs no ambiente de gelo, até 5 NPCs permanecem ativos simultaneamente em 100% dos quadros, o teto nunca é excedido e 100% dos pares relevantes de aproximação entre eles são avaliados.
- **SC-012**: 100% das mudanças relevantes da velocidade do jogador (deixar de acelerar, desacelerar, frear) disparam reavaliação das condições de colisão, e 0 colisões são registradas sem que a regra da janela de atividade seja satisfeita.
- **SC-013**: Uma formação inicialmente segura passa a produzir previsão de colisão após mudança relevante da velocidade do jogador em 100% dos ensaios em que a permanência conjunta na área ativa se torna suficiente, e não produz previsão nos ensaios em que permanece insuficiente.
- **SC-014**: A velocidade de qualquer NPC é idêntica antes, durante e depois de qualquer colisão ou sequência de colisões, em 100% dos quadros dos ensaios (0 variações, nem temporárias).
- **SC-015**: Em 100% dos casos, um NPC deslocado por colisão NPC×NPC que atinge o jogador produz exatamente 1 evento do sistema da SPEC-005, sem lógica de colisão jogador×NPC duplicada.
- **SC-016**: Zero regressões: 100% dos comportamentos das SPEC-001 a SPEC-005 permanecem funcionais, verificados pelas suas suítes de teste com o novo sistema ativo.
- **SC-017**: Todos os parâmetros listados em FR-044 podem ser ajustados somente por configuração, sem nenhuma alteração de código, e cada alteração produz efeito observável no jogo.
- **SC-018**: Durante toda a sequência 2 vias → 4 vias → 2 vias com formação de NPCs ativa, 0 veículos saem da área trafegável, 0 colisões são perdidas por uso de largura fixa e o sistema opera com os limites vigentes em 100% dos quadros.
- **SC-019**: Com o jogador e até 5 NPCs ativos, o jogo mantém 60 quadros por segundo como meta e nunca fica abaixo de 30 quadros por segundo de forma recorrente durante partidas contínuas de 10 minutos.

## Assumptions

- Os SPEC-001 a SPEC-005 estão concluídos e funcionais. Esta spec estende o jogo sem alterar o comportamento das features anteriores; em particular, o sistema de colisão jogador×NPC da SPEC-005 permanece intacto e é a destino de qualquer contato NPC → jogador decorrente de um deslocamento.
- **Escopo das consequências de colisão da constituição (§Comportamento de Colisão)**: os itens "reduzir a velocidade do veículo" e "consumir combustível adicional" referem-se às colisões envolvendo o veículo do jogador, que é o único veículo com combustível e com penalidade de velocidade prevista. Colisão NPC×NPC é uma interação interna do trânsito: sua consequência perceptível é o drift e o deslocamento lateral temporários, a cadeia de impactos e o evento emitido — coerente com a proibição, nesta spec, de **qualquer** mudança de velocidade do NPC por colisão (FR-017), e com a ausência de sistema de combustível nos NPCs.
- **Escopo da detecção de colisão da constituição (§Trânsito)**: os veículos de trânsito continuam apenas fornecendo identificação, posição e área ocupada; a detecção e a resolução NPC×NPC ficam num componente próprio dedicado, e não nos veículos individuais, preservando a separação de responsabilidades exigida (§III — Arquitetura Modular). A responsabilidade de colisão jogador×NPC permanece no sistema de colisão da SPEC-005, sem duplicação.
- As velocidades-base são as da tabela do texto-fonte (caminhão 90, esporte 120, passeio 100, utilitário 90 km/h; jogador 125 km/h), poderão ser alteradas pelo sistema de dificuldade futuro (SPEC-008) e devem ser tratadas como valores que podem variar durante a execução.
- A velocidade efetiva de cada NPC e a progressão relativa na tela continuam determinadas pelo SPEC-004 (diferença entre a velocidade do veículo e a velocidade da estrada). O relativo entre dois NPCs na tela independe da velocidade do jogador; o que a velocidade do jogador altera é o **tempo de permanência** de cada um na área ativa — e, portanto, a janela de atividade conjunta. É sobre essa janela que a reavaliação da US8 opera.
- O SPEC-004 reserva corredores laterais por velocidade no nascimento, mas velocidades diferentes ainda podem dividir a mesma trajetória: além dos deslocamentos laterais (ultrapassagem do SPEC-005, drift desta spec, transição de largura), o próprio trânsito gera compartilhamento — recuo de faixa no nascimento, nascimentos adjacentes e convergência ao estreitar a pista. A avaliação considera sempre a trajetória atual dos veículos, não a do nascimento. **Dívida conhecida da SPEC-004**, fora do escopo desta spec e tratada em spec própria: (a) o recuo de faixa do nascimento pode posicionar um veículo na faixa de outra velocidade; (b) ao estreitar a pista, o reaplicar dos limites pode convergir dois veículos de faixas distintas para a mesma faixa sem nova checagem de ordenação ou de separação.
- O teto de NPCs ativos (`npc_max_active`) reutiliza o teto por nível de dificuldade já definido no SPEC-004 (FR-064): 5 no ambiente de gelo, configurável por nível.
- As áreas físicas usadas na detecção NPC×NPC são as mesmas áreas físicas configuráveis dos veículos de trânsito adotadas pela SPEC-005, independentes dos sprites; esta spec não introduce um segundo conjunto de hitboxes por veículo.
- A normalização da intensidade do impacto segue a mesma convenção da SPEC-005 (velocidade relativa no contato, normalizada em intervalo de 0 a 1 com divisor configurável), para manter comportamento consistente entre os dois sistemas de colisão.
- Cooldown, cadeia, drift e deslocamento não alteram a velocidade da estrada nem a velocidade dos NPCs em nenhuma fase; portanto não interferem no scroll, na dificuldade nem no consumo de combustível do jogador.
- A reavaliação periódica e o limiar de "mudança relevante" são configuráveis: a spec exige que a reavaliação **possa** ocorrer, não a frequência exata — o equilíbrio entre custo e respostividade fica para o planejamento.
- Nenhum áudio, efeito visual, partícula, pontuação ou sistema de dificuldade é implementado por esta spec: apenas o evento é emitido, pronto para ser observado no futuro.
- Nenhum sistema de dano, destruição, explosão ou Game Over é afetado; colisão entre NPCs nunca interrompe a partida.
- Os 26 cenários de teste obrigatórios do texto-fonte (seção "Testes obrigatórios") estão cobertos pelas Acceptance Scenarios das nove histórias de usuário (US1: teste 5; US2: 1–4; US3: 6; US4: 7, 8, 9, 25, 26; US5: 10–14; US6: estado e evento; US7: 15–18; US8: 20–23; US9: 19, 24).

## Out of Scope

Os itens a seguir estão explicitamente fora do escopo desta especificação e não devem ser implementados:

- Colisão jogador × NPC (permanece exclusivamente com o sistema da SPEC-005).
- Perda de combustível e penalidade de combustível.
- Game Over, Victory e qualquer transição de estado global.
- Destruição de veículos, dano estrutural e explosões.
- Física veicular realista, capotamento e rotação física dos veículos.
- Inteligência artificial avançada, frenagem inteligente dos NPCs, mudança permanente de velocidade, tomada de decisão estratégica e comportamento de perseguição.
- Tráfego em sentido contrário.
- Pontuação, telemetria persistente, efeitos visuais/sonoros e partículas (o evento fica disponível, mas nada os consome nesta versão).
- Obstáculos, decoração com colisão e colisões com elementos decorativos.
