# Feature Specification: Sistema de Combustível

**Feature Branch**: `007-fuel-system`

**Created**: 2026-10-09

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-007 — Sistema de Combustível" (capacidade configurável do tanque e inicialização cheia por partida, consumo contíguo calculado pelo tempo decorrido e proporcional à velocidade entre consumo mínimo e máximo, consumo em repouso, penalidade de colisão variável por ambiente — zero em planície e deserto, pequena e acumulativa em floresta e gelo, uma única vez por colisão válida do jogador e nunca por colisões exclusivamente entre NPCs —, detecção de combustível baixo e esgotado com eventos únicos, disponibilização dos dados para a interface, configuração centralizada dos parâmetros para balanceamento e integração com as SPEC-005, SPEC-006 e SPEC-008 sem duplicar responsabilidades).

## Clarifications

### Session 2026-10-09

- Q: O texto-fonte exige que "a interface apresente o nível atual de combustível" e manda respeitar "o padrão de interface já utilizado no projeto", mas o projeto não possui nenhuma interface — qual escopo de apresentação a SPEC-007 deve adotar? (FR-025) → A: **Indicador visual mínimo** — barra de combustível e sinalização de combustível baixo na partida, sem sons, animações ou efeitos avançados. É o primeiro elemento de interface do projeto; o padrão visual exato (posição, cores, estilo) fica para o planejamento, respeitando a constituição.
- Q: Como o indicador deve sinalizar ao jogador que o combustível ficou baixo, para que a condição seja visível e testável? (FR-025) → A: **Mudança de cor da barra + rótulo/ícone estático de alerta** ao lado da barra (ex.: "BAIXO"), mantidos enquanto durar a condição — sem animações nem sons.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Administrar o combustível consumido ao longo da corrida (Priority: P1)

O jogador larga com o tanque cheio e o combustível é consumido continuamente enquanto a corrida acontece: mais rápido a velocidade, maior o consumo por segundo; em repouso, vale o consumo em repouso configurável; ao acelerar, frear ou soltar o acelerador, o consumo acompanha a mudança de velocidade. O valor nunca fica negativo nem ultrapassa a capacidade, a inicialização acontece exatamente uma vez por partida e a mesma duração produz o mesmo consumo independentemente da taxa de atualização. Todos os parâmetros do modelo vêm da configuração.

**Why this priority**: É o núcleo da spec — sem consumo iniciado cheio, tempo-dependente e limitado, não existe recurso a administrar nem base para penalidades, esgotamento ou interface. É o MVP: sozinho já entrega a mecânica de gerenciar velocidade para a corrida durar.

**Independent Test**: Iniciar partidas sintéticas em velocidades constantes baixa e alta e conferir que o total consumido na alta é maior; repetir a mesma duração em taxas de atualização diferentes e conferir o mesmo total; rodar até zerar e conferir que o valor para em zero; verificar inicialização cheia e ausência de re-inicialização durante a corrida. Validável sem penalidades, eventos ou interface.

**Acceptance Scenarios**:

1. **Given** uma nova partida, **When** a corrida inicia, **Then** a quantidade atual é exatamente igual à capacidade configurada.
2. **Given** um valor inicial configurado dentro do intervalo válido, **When** a corrida inicia, **Then** a partida começa com exatamente esse valor; se o valor configurado estiver fora do intervalo, ele é limitado aos limites válidos.
3. **Given** o jogador em velocidade baixa e, em outro ensaio, em velocidade alta mantidas constantes, **When** o mesmo tempo decorre nos dois casos, **Then** o consumo total na velocidade alta é maior ou igual ao da velocidade baixa.
4. **Given** o jogador mantendo uma velocidade constante, **When** o tempo decorre, **Then** o consumo continua ocorrendo sem interrupção.
5. **Given** o jogador acelerando, **When** a velocidade sobe, **Then** a taxa de consumo acompanha a velocidade alcançada segundo o modelo linear configurado.
6. **Given** o jogador deixando de acelerar, **When** a velocidade cai (desaceleração natural), **Then** a taxa de consumo dos quadros seguintes corresponde à nova velocidade menor — nunca permanece no valor anterior.
7. **Given** o jogador freando, **When** a velocidade cai, **Then** o consumo acompanha a redução segundo o modelo configurado.
8. **Given** o veículo parado (velocidade zero), **When** o tempo decorre, **Then** o consumo segue exatamente o parâmetro de consumo em repouso, que pode ser zero.
9. **Given** a mesma corrida e o mesmo percurso, **When** executados em taxas de atualização diferentes (por exemplo, 30, 60 e 120 atualizações por segundo), **Then** o consumo total é o mesmo — ele depende do tempo decorrido, não do número de atualizações.
10. **Given** o consumo avançando até o fim do combustível, **When** a quantidade chegaria abaixo de zero, **Then** ela para exatamente em zero e jamais ultrapassa a capacidade máxima em nenhuma atualização.

---

### User Story 2 - Sofrer consequência de combustível nas colisões conforme o ambiente (Priority: P1)

Nos ambientes iniciais, colidir com o trânsito afeta apenas a dirigibilidade, como sempre — nenhum consumo extra de combustível. Na floresta e no gelo, cada colisão válida do jogador com um NPC desconta um pequeno valor configurável, que se acumula a cada colisão distinta e somente enquanto o jogador estiver envolvido: colisões exclusivamente entre NPCs não tocam no combustível dele. A penalidade usa o ambiente vigente no instante da colisão e nunca leva o valor a ficar negativo.

**Why this priority**: É a progressão de dificuldade que amarra o combustível às colisões da SPEC-005 e isola as colisões da SPEC-006 — transforma "evitar colisão" em consequência real nos ambientes avançados. Depende apenas do consumo da US1 e do evento de colisão já existente.

**Independent Test**: Apresentar eventos de colisão válida jogador×NPC em cada um dos quatro ambientes e medir a variação do combustível (0, 0, pequeno, pequeno); repetir a mesma colisão várias vezes e conferir o acúmulo; apresentar uma colisão NPC×NPC e conferir variação zero; mudar o ambiente entre colisões e conferir o valor aplicado ao novo.

**Acceptance Scenarios**:

1. **Given** o ambiente de planície, **When** ocorre uma colisão válida do jogador com um NPC, **Then** a perda de combustível adicional é exatamente zero — apenas o consumo normal continua valendo.
2. **Given** o ambiente de deserto, **When** ocorre uma colisão válida do jogador com um NPC, **Then** a perda de combustível adicional é exatamente zero.
3. **Given** o ambiente de floresta, **When** ocorre uma colisão válida do jogador com um NPC, **Then** é descontado o pequeno valor configurado para floresta.
4. **Given** o ambiente de gelo, **When** ocorre uma colisão válida do jogador com um NPC, **Then** é descontado o pequeno valor configurado para gelo.
5. **Given** os valores configurados de floresta e gelo, **When** são comparados, **Then** são equivalentes entre si nesta versão inicial.
6. **Given** colisões distintas em floresta (ou gelo), **When** cada uma é validada, **Then** cada desconto se acumula ao anterior, além do consumo normal — três colisões produzem três descontos.
7. **Given** uma mesma colisão com as áreas ainda sobrepostas, **When** o tempo passa, **Then** no máximo um desconto é aplicado — a penalidade não se repete enquanto o contato contínuo durar, e o cooldown/identificador de colisão existente é respeitado.
8. **Given** uma colisão exclusivamente entre NPCs conforme a SPEC-006, **When** ela ocorre, **Then** o combustível do jogador não é alterado por ela.
9. **Given** o jogador em deserto com uma colisão já registrada, **When** o ambiente muda para gelo e uma nova colisão é validada, **Then** a nova colisão usa o valor de gelo e nenhuma penalidade retroativa é aplicada às anteriores.
10. **Given** um saldo menor que o valor da penalidade, **When** a colisão é validada, **Then** o combustível zera exatamente em zero — nunca negativo — e o esgotamento é detectado normalmente.

---

### User Story 3 - Ser avisado uma única vez quando o combustível esgotar (Priority: P1)

Quando o combustível chega a zero — pelo consumo normal, pelo acúmulo de penalidades ou pela combinação dos dois —, o sistema detecta o esgotamento na origem que for e emite um único aviso. Depois disso nada mais consome combustível e nenhuma operação leva o valor a ficar negativo. O sistema não encerra a partida nem mexe na física: ele apenas comunica, deixando a decisão de gameplay para o sistema de estados da SPEC-008.

**Why this priority**: É o gatilho que a SPEC-008 vai consumir para vitória, Game Over e progressão — sem o evento único e confiável, o estado da corrida não tem sinal confiável para reagir. Depe do consumo da US1 e das penalidades da US2.

**Independent Test**: Zerar o tanque por puro consumo e conferir exatamente um evento; zerar por penalidade em gelo e conferir exatamente um evento; continuar rodando após zero e conferir que o valor permanece em zero sem novos eventos; conferir que nenhuma tela de fim de jogo apareceu e que a velocidade não foi alterada.

**Acceptance Scenarios**:

1. **Given** o combustível caindo continuamente, **When** o consumo cruza zero, **Then** a quantidade para exatamente em zero e o esgotamento é detectado no mesmo instante.
2. **Given** qualquer operação que tentaria reduzir um valor já zerado, **When** ela é aplicada, **Then** o resultado permanece em zero — nenhum valor negativo é produzido.
3. **Given** o tanque esgotado, **When** a corrida continua, **Then** nenhum consumo adicional ocorre e nenhuma penalidade consegue reduzir o valor.
4. **Given** um esgotamento (por consumo, por penalidade ou por combinação), **When** o tempo continua correndo, **Then** exatamente um evento de esgotamento foi emitido — nunca um por atualização.
5. **Given** o esgotamento detectado, **When** é observado o restante do jogo, **Then** nenhuma tela de Game Over foi implementada por este sistema, nenhuma velocidade ou física foi alterada, e o sistema de estados pode se integrar ao aviso sem duplicar lógica de movimento.

---

### User Story 4 - Acompanhar o nível de combustível e o alerta de baixo na tela (Priority: P2)

O jogador precisa ver quanto combustível resta para poder administrar a velocidade: a interface recebe a quantidade atual e a capacidade e apresenta o nível numa barra de combustível, acompanhando-a a cada alteração. Quando a razão entre atual e capacidade cruza o limite configurável de combustível baixo, a barra muda de cor e um rótulo estático de alerta (ex.: "BAIXO") aparece ao lado dela enquanto a condição persistir — sem sons nem animações —, sem jamais calcular ou alterar o combustível.

**Why this priority**: Sem visibilidade do nível, a mecânica da US1 é invisível e o jogador não consegue administrar nada — mas a apresentação só faz sentido depois que os dados e os eventos existem (US1, US3). Por isso P2.

**Independent Test**: Alterar o combustível e conferir que a barra apresentada acompanha o novo valor; aproximar o valor do limite configurável e conferir a sinalização de baixo; tentar modificar o combustível pela camada de apresentação e conferir que nada muda.

**Acceptance Scenarios**:

1. **Given** o limite de combustível baixo configurado, **When** a razão atual/capacidade cruza o limite para baixo, **Then** a barra do indicador muda de cor e o rótulo estático de alerta é exibido ao lado dela, o estado de combustível baixo fica sinalizado e o evento correspondente é emitido sem repetição desnecessária enquanto a condição persistir.
2. **Given** qualquer alteração real do combustível (consumo ou penalidade), **When** ela ocorre, **Then** os dados disponibilizados para a interface refletem imediatamente o novo valor junto com a capacidade.
3. **Given** a camada de apresentação, **When** ela consome os dados, **Then** ela apenas exibe — nenhum cálculo de consumo nem modificação da quantidade parte da interface.
4. **Given** o indicador de combustível apresentado na partida, **When** a quantidade atual muda por consumo ou penalidade, **Then** o indicador acompanha a nova situação na mesma variação — ele reflete o valor recebido, nunca o recalcula.

---

### User Story 5 - Ajustar o balanceamento sem mexer na lógica (Priority: P2)

Os valores de combustível são calibrados por testes de gameplay: duração de corrida compatível com a pista, consumo perceptível mas administrável, penalidades pequenas nos ambientes avançados, possibilidade de terminar a corrida depois de algumas colisões e risco real de esgotamento com excesso de colisões. Para iterar esses valores, basta alterar a configuração — capacidade, consumos, fator de velocidade, limiar de baixo e penalidades por ambiente ficam centralizados, sem números fixos na lógica.

**Why this priority**: O balanceamento será iterativo várias vezes depois da implementação; deixá-lo por último ou espalhado pelo código multiplicaria retrabalho. Importante, porém dependente do modelo já existir (US1–US4).

**Independent Test**: Alterar cada parâmetro listado apenas pela configuração e observar o efeito correspondente no jogo; conferir que nenhum teste anterior quebra e que nenhum arquivo de lógica precisou mudar.

**Acceptance Scenarios**:

1. **Given** os parâmetros de combustível centralizados na configuração, **When** cada um deles é alterado, **Then** o efeito correspondente aparece no jogo sem nenhuma alteração na lógica central.
2. **Given** a calibração de balanceamento, **When** os valores são escolhidos, **Then** eles cumprem os critérios mensuráveis do FR-028 (esgotamento entre 45 e 90 segundos em velocidade máxima; penalidade de floresta e gelo entre 2% e 10% da capacidade, iguais entre si) e são definidos por testes de gameplay, não arbitrariamente.

---

### Edge Cases

- Penalidade maior que o saldo disponível: o valor zera exatamente em zero e o esgotamento é detectado pela origem "colisão".
- Consumo e penalidade atuando no mesmo quadro até o fim do combustível: ambos são aplicados dentro dos limites, o resultado é zero e apenas um evento de esgotamento é emitido.
- Colisão validada com o tanque já esgotado: nenhuma redução e nenhum novo evento de esgotamento.
- Várias colisões válidas no mesmo quadro: cada uma produz no máximo um desconto, todas limitadas pelo zero.
- Mudança de ambiente entre duas colisões: a primeira usa o valor do ambiente antigo já aplicado, a segunda usa o novo — nada retroativo.
- Velocidade acima da máxima (se ocorrer): a normalização é limitada ao intervalo de 0 a 1 e a taxa não ultrapassa o consumo máximo.
- Velocidade fora do intervalo esperado (inclusive negativa por qualquer causa): tratada pelo piso do intervalo, sem consumo negativo.
- Configuração inválida de capacidade (zero): a avaliação do limiar percentual não pode produzir divisão por zero.
- Quantidade inicial configurada acima da capacidade ou abaixo de zero (fora do sentinela de "não configurado"): limitada ao intervalo válido antes da partida começar.
- Partida iniciada com o valor já abaixo do limiar de combustível baixo: o estado de baixo é sinalizado desde o início, sem eventos duplicados.
- Queda brusca de atualização (delta grande): um único passo consome no máximo a taxa correspondente ao tempo decorrido e respeita os limites; se esgotar no meio do passo, para em zero e emite um evento.
- Repouso com o parâmetro de consumo em repouso definido como zero: veículo parado não consome nada.
- Reinício de partida (sem a SPEC-008 ainda orquestrando): nova chamada de inicialização recheia o tanque e rearma os eventos de baixo e esgotado.
- Limiar de combustível baixo exatamente igual à razão atual: a condição "menor ou igual" vale e o estado é sinalizado.
- Esgotamento seguido de novas tentativas de consumo ou penalidade: valor permanece em zero, evento não se repete.

## Requirements *(mandatory)*

### Functional Requirements

**Capacidade e inicialização**

- **FR-001**: O sistema deve manter uma capacidade máxima de tanque configurável e uma quantidade atual de combustível, usando uma unidade única e consistente em todo o sistema — recomenda-se unidade abstrata de combustível, sem simulação de litros reais.
- **FR-002**: Toda nova partida deve iniciar com o tanque cheio, e a inicialização deve ocorrer exatamente uma vez por partida — sem reinicialização acidental durante movimentação, colisões ou mudanças na configuração da pista.
- **FR-003**: A quantidade inicial de combustível deve poder ser configurada dentro dos intervalos válidos (entre zero e a capacidade), tendo o tanque cheio como padrão; o valor sentinela de "não configurado" equivale ao tanque cheio, e qualquer outro valor fora do intervalo válido deve ser limitado aos limites válidos.

**Consumo durante a corrida**

- **FR-004**: Enquanto a corrida estiver em andamento, o consumo deve ocorrer continuamente em todos os ambientes, independentemente da ação do jogador — ausência de penalidade num ambiente não suspende o consumo.
- **FR-005**: O consumo deve ser calculado com base no tempo decorrido e não no número de atualizações executadas: a mesma duração deve produzir o mesmo consumo em diferentes taxas de atualização.
- **FR-006**: A taxa de consumo deve variar conforme a velocidade atual do jogador de maneira linear e crescente, partindo do consumo mínimo em velocidade baixa e subindo na proporção do fator de velocidade configurável até o consumo máximo, ambos previstos na configuração; velocidades mais elevadas devem produzir consumo igual ou maior.
- **FR-007**: A velocidade usada no modelo de consumo deve ser normalizada entre zero e a velocidade máxima configurada, com o resultado limitado ao intervalo de 0 a 1 mesmo quando a velocidade exceder a máxima.
- **FR-008**: Acelerar deve elevar o consumo na medida da velocidade alcançada, e deixar de acelerar ou frear deve reduzir o consumo na medida da queda de velocidade — as duas variações acompanham o modelo baseado em velocidade adotado, sem comportamento adicional inventado.
- **FR-009**: Com o veículo em repouso (velocidade zero), o consumo deve seguir o parâmetro de consumo em repouso, que poderá ser zero; nenhum comportamento adicional, como desligamento automático do motor, pode existir sem decisão específica de design.
- **FR-010**: Em qualquer atualização, a quantidade atual deve permanecer limitada ao intervalo de zero à capacidade: o sistema não pode produzir valores negativos nem ultrapassar a capacidade máxima.

**Penalidade de combustível por colisão**

- **FR-011**: Cada colisão válida entre o jogador e um NPC, segundo as regras da SPEC-005, deve resultar em desconto de combustível conforme o ambiente vigente no momento da colisão: exatamente zero em planície e deserto; um pequeno valor configurável em floresta e gelo, inicialmente equivalente entre esses dois ambientes.
- **FR-012**: O consumo normal do motor deve permanecer ativo em todos os ambientes — a ausência de penalidade em planície e deserto não significa que o veículo deixe de consumir.
- **FR-013**: Cada colisão válida pode produzir no máximo um desconto: a penalidade não deve ser aplicada continuamente enquanto as áreas dos envolvidos permanecerem sobrepostas, e o cooldown ou identificador de colisão existente deve ser respeitado.
- **FR-014**: Os descontos de colisões distintas devem ser acumulativos e aplicados além do consumo normal.
- **FR-015**: Colisões exclusivamente entre NPCs, conforme a SPEC-006, não podem reduzir o combustível do jogador.
- **FR-016**: A penalidade deve considerar o ambiente validado no momento da colisão; mudanças de ambiente não podem aplicar penalidades retroativas, e a configuração aplicável deve acompanhar o ambiente ativo para as próximas colisões.
- **FR-017**: A penalidade deve ser limitada pela quantidade disponível — o resultado nunca fica abaixo de zero —; uma colisão que esgotaria o tanque zera o combustível e dispara a detecção de esgotamento como qualquer outra origem.

**Esgotamento do combustível**

- **FR-018**: O esgotamento deve ser detectado independentemente da origem (consumo normal, acúmulo de penalidades ou combinação dos dois) e deve emitir um evento de esgotamento.
- **FR-019**: O evento de esgotamento deve ocorrer exatamente uma vez por ocorrência — nunca uma vez por atualização —, sendo rearmado somente em nova partida.
- **FR-020**: Esgotado o combustível, novos consumos devem ser impedidos e nenhuma operação pode levar a quantidade abaixo de zero.
- **FR-021**: O sistema não deve implementar Game Over nem alterar velocidade, aceleração ou física do veículo; a política de gameplay pós-esgotamento (impedir aceleração, permitir desaceleração natural, encerrar a partida etc.) é responsabilidade do sistema de estados da SPEC-008, que deve poder se integrar ao aviso sem duplicar lógica de movimento.

**Combustível baixo e disponibilização de dados**

- **FR-022**: Deve existir um limite configurável de combustível baixo, expresso como percentual da capacidade, avaliado pela razão entre a quantidade atual e a capacidade (menor ou igual ao limite).
- **FR-023**: Ao cruzar o limite para baixo, o sistema deve emitir um evento de combustível baixo sem repetição desnecessária enquanto a condição persistir, e o estado de combustível baixo deve ficar disponível para consulta.
- **FR-024**: O sistema deve disponibilizar aos observadores, segundo as convenções do projeto, a quantidade atual e a capacidade máxima, além dos eventos de mudança de combustível, combustível baixo e esgotamento; cada mudança notificada deve refletir uma alteração real do valor.
- **FR-025**: A interface deve apresentar o nível atual de combustível por meio de um indicador visual mínimo — barra de combustível na partida —, sinalizar o estado de combustível baixo com mudança de cor da barra e rótulo/ícone estático de alerta ao lado (mantidos enquanto durar a condição) e acompanhar cada alteração, sem calcular consumo nem modificar a quantidade; sons, animações e efeitos visuais avançados não são obrigatórios nesta especificação.

**Configuração e balanceamento**

- **FR-026**: Todos os parâmetros de combustível devem estar centralizados na configuração do projeto e ser ajustáveis sem alteração da lógica central — nenhum valor de balanceamento pode estar fixo no código.
- **FR-027**: Os parâmetros previstos (nomes de referência, adaptáveis à convenção do projeto) são: capacidade do tanque, quantidade inicial, consumo em repouso, consumo mínimo, consumo máximo, fator de velocidade do consumo, limite de combustível baixo e penalidade de colisão por ambiente (planície, deserto, floresta, gelo).
- **FR-028**: Os valores iniciais devem ser calibrados por testes de gameplay para buscar: duração de corrida provisória mensurável — tanque cheio esgotando entre 45 e 90 segundos em velocidade máxima (referência provisória, reaberta quando a extensão real da pista existir, com a SPEC de progressão de pista), consumo perceptível mas administrável, penalidades de floresta e gelo equivalentes entre si e cada uma entre 2% e 10% da capacidade do tanque por colisão, possibilidade de terminar a corrida mesmo após algumas colisões e risco real de esgotamento quando houver excesso de colisões — a penalidade não pode ser tão alta que colisões inevitáveis tornem a corrida impossível, nem tão baixa que colidir repetidamente em floresta ou gelo não tenha consequência relevante.

**Responsabilidades, integração e escopo**

- **FR-029**: O sistema de combustível deve ser um componente próprio, responsável por manter a quantidade atual, controlar a capacidade, calcular o consumo, aplicar penalidades por colisão, detectar combustível baixo e esgotado, emitir eventos e expor os dados — sem assumir responsabilidades de movimento, colisão, interface ou estados.
- **FR-030**: O sistema de movimento do jogador deve disponibilizar a velocidade atual, a velocidade máxima e o estado de movimento necessários ao cálculo; o sistema de combustível não deve duplicar lógica de movimento.
- **FR-031**: O sistema de colisão jogador×NPC (SPEC-005) permanece responsável pela detecção e classificação das colisões e não modifica combustível diretamente; a integração com o sistema de combustível ocorre pelo evento de colisão já disponível ou por interface equivalente, conforme a arquitetura existente.
- **FR-032**: Os sistemas de trânsito e de colisão entre NPCs (SPEC-004 e SPEC-006) não devem aplicar penalidades de combustível ao jogador em colisões das quais ele não participa.
- **FR-033**: A inicialização de nova partida e a reação ao esgotamento devem poder integrar-se ao sistema de estados do jogo previsto na SPEC-008, sem duplicar responsabilidades; esta especificação não implementa estados, vitória nem Game Over.
- **FR-034**: A nomenclatura dos parâmetros e eventos deve seguir as convenções já adotadas pelo projeto, mantendo a mesma família de prefixo usada pelos demais subsistemas configuráveis.

**Parâmetros configuráveis** (nomes de referência, adaptáveis à convenção do projeto):

- `fuel_capacity` — capacidade máxima do tanque;
- `fuel_initial_amount` — quantidade inicial (padrão: tanque cheio);
- `fuel_consumption_idle` — consumo em repouso (velocidade zero);
- `fuel_consumption_min` — consumo mínimo durante a movimentação;
- `fuel_consumption_max` — consumo máximo na configuração;
- `fuel_consumption_speed_factor` — fator com que a velocidade influencia o consumo;
- `fuel_low_threshold` — limite de combustível baixo (percentual da capacidade);
- `collision_fuel_penalty` — penalidade por colisão por ambiente (`PLAINS`, `DESERT`, `FOREST`, `ICE`).

### Key Entities *(include if feature involves data)*

- **Estado de Combustível**: quantidade atual e capacidade máxima do tanque da partida corrente. Unidade abstrata consistente; invariantes: `0 ≤ atual ≤ capacidade`; nasce cheio a cada partida e só pode ser alterado pelo consumo ou por penalidades de colisão.
- **Configuração de Combustível**: conjunto centralizado dos parâmetros da lista acima (capacidade, inicial, repouso, mínimo, máximo, fator de velocidade, limiar de baixo e penalidades por ambiente). Legível pelos sistemas sem alteração de código; origem única dos valores de balanceamento.
- **Evento de Mudança de Combustível**: notificação com a quantidade atual e a capacidade, emitida quando o valor sofre alteração real; destinada a observadores como a interface.
- **Evento de Combustível Baixo**: notificação emitida quando a razão atual/capacidade cruza o limite configurável (menor ou igual), acompanhada dos valores que originaram a condição; uma vez por travessia, sem repetição enquanto persistir.
- **Evento de Esgotamento**: notificação de ocorrência (sem payload obrigatório) registrada quando a quantidade atinge zero, seja qual for a origem; exatamente uma por esgotamento, rearmed na nova partida.
- **Penalidade por Colisão**: desconto contextual aplicado a uma colisão válida do jogador. Atributos: ambiente vigente no momento da validação, valor configurado daquele ambiente e o saldo resultante limitado ao zero. Inexiste para colisões exclusivamente entre NPCs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das novas partidas, a quantidade inicial é exatamente igual à capacidade configurada; o número de inicializações por partida é exatamente 1 (0 reinicializações acidentais durante a corrida).
- **SC-002**: Com a quantidade inicial configurada dentro do intervalo válido, 100% das partidas iniciam com exatamente esse valor; configurações fora do intervalo válido — exceto o sentinela de "não configurado", que resulta em tanque cheio — resultam em valor limitado aos limites válidos em 100% dos casos.
- **SC-003**: Partidas com mesmo percurso e mesma velocidade produzem consumo total idêntico (dentro da tolerância de arredondamento) em taxas de atualização diferentes — por exemplo, 30, 60 e 120 atualizações por segundo —, com desvio entre elas menor que 1%.
- **SC-004**: Em 100% dos ensaios comparando velocidades constantes, a velocidade alta produz consumo por segundo maior ou igual ao da velocidade baixa, e o consumo cresce monotonicamente com a velocidade segundo o modelo linear configurado.
- **SC-005**: Após deixar de acelerar ou frear, 100% dos quadros seguintes aplicam a taxa de consumo correspondente à velocidade atual daquele quadro — 0 quadros com a taxa da velocidade anterior.
- **SC-006**: Com o veículo em velocidade zero, 100% dos quadros aplicam exatamente o consumo em repouso configurado.
- **SC-007**: Em partidas contínuas de 10 minutos com colisões nos quatro ambientes, 0 ocorrências de quantidade menor que zero ou maior que a capacidade.
- **SC-008**: Em planície e deserto, 100% das colisões válidas do jogador com NPCs produzem perda adicional de combustível exatamente igual a zero — somente o consumo normal é contabilizado.
- **SC-009**: Em floresta e gelo, cada colisão válida aplica exatamente 1 desconto do valor configurado e N colisões distintas produzem exatamente N descontos acumulados (100% dos ensaios); os valores iniciais dos dois ambientes são iguais (equivalência em 100% das comparações).
- **SC-010**: Durante o contato contínuo de uma mesma colisão, no máximo 1 desconto é aplicado — 0 penalidades duplicadas em 100% dos ensaios de sobreposição prolongada.
- **SC-011**: Colisões exclusivamente entre NPCs produzem 0 reduções no combustível do jogador em 100% dos ensaios.
- **SC-012**: Após mudança de ambiente, 100% das novas colisões usam o valor do ambiente novo e 0 penalidades retroativas são aplicadas a colisões anteriores.
- **SC-013**: O esgotamento é detectado em 100% dos casos por qualquer origem (consumo, penalidade ou combinação); exatamente 1 evento é emitido por ocorrência (0 eventos repetidos por atualização); após o esgotamento, 0 consumos e 0 valores negativos.
- **SC-014**: O estado de combustível baixo é sinalizado em 100% das travessias do limiar configurado — com a mudança de cor da barra e o rótulo estático de alerta visíveis enquanto a condição persistir —, com 0 emissões repetidas do evento.
- **SC-015**: 100% das alterações reais do combustível se refletem nos dados observados (quantidade atual e capacidade) e no indicador apresentado; a camada de apresentação produz 0 modificações no combustível.
- **SC-016**: Todos os parâmetros listados são alteráveis somente por configuração, sem alteração de código, e cada alteração produz efeito observável em 100% dos casos — 0 valores de balanceamento fixos na lógica.
- **SC-017**: Zero regressões: 100% dos comportamentos das SPEC-001 a SPEC-006 permanecem funcionais, verificados pelas suas suítes de teste com o sistema de combustível ativo.
- **SC-018**: Com o tanque cheio e o veículo mantendo a velocidade máxima, o esgotamento ocorre entre 45 e 90 segundos em 100% dos ensaios de calibração (benchmark provisório do FR-028, reaberto quando a extensão real da pista existir).
- **SC-019**: Em floresta e gelo, cada colisão válida desconta um valor entre 2% e 10% da capacidade, idêntico entre os dois ambientes, em 100% das comparações de calibração.

## Assumptions

- As SPEC-001 a SPEC-006 estão concluídas e funcionais (SPEC-005 fornece o evento de colisão jogador×NPC; SPEC-006 fornece colisões NPC×NPC que permanecem sem efeito sobre o combustível). Esta spec estende o jogo sem alterar o comportamento das features anteriores.
- **Unidade abstrata**: o combustível não é medido em litros reais; usa-se uma unidade abstrata consistente, que permite calibrar a duração da corrida sem simulação desnecessária.
- **Quantidade inicial**: padrão = tanque cheio, conforme a regra de inicialização; o parâmetro configurável existe para testes de balanceamento, com o valor padrão igual ao sentinela de "não configurado" (fora do intervalo), que resolve para tanque cheio — qualquer outro valor é limitado ao intervalo válido.
- **Modelo de consumo baseado em velocidade**: acelerar, soltar o acelerador e frear refletem no consumo por meio da própria velocidade — a SPEC-001 já prevê aceleração e desaceleração natural, portanto o consumo acompanha a velocidade em cada atualização, sem fator adicional de acelerador. A fórmula de interpolação do texto-fonte é a referência inicial, não exigência literal.
- **Consumo em repouso**: o parâmetro poderá ser adotado como zero se o jogo não precisar de consumo com o veículo parado; nenhum desligamento automático do motor existe.
- **Penalidades de floresta e gelo**: pequenas e equivalentes nesta versão; banda provisória de 2% a 10% da capacidade do tanque por colisão (SC-019), a confirmar na calibração — os valores definitivos serão escolhidos por testes de gameplay depois de validar capacidade, consumo e duração esperada — nunca arbitrariamente.
- **Limiar de combustível baixo**: percentual da capacidade (recomendação do texto-fonte); o valor inicial de percentual é definido no planejamento/calibração.
- **Evento de mudança de combustível**: emitido quando o valor se altera de fato; a granularidade exata (a cada variação ou por quadro com variação) segue a convenção do projeto definida no planejamento.
- **Evento de combustível baixo**: uma emissão por travessia do limiar; como não existe reabastecimento nesta spec, não há rearme além do nova partida.
- **Ambiente atual**: obtido do sistema de ambientes da SPEC-003 no momento em que a colisão é validada; o jogo pode manter o ambiente fixo por partida — a regra "sem retroatividade e valor do ambiente ativo" cobre tanto o caso atual quanto uma eventual transição futura.
- **Colisões válidas**: a detecção, a classificação e o cooldown de colisão jogador×NPC permanecem exclusivamente com a SPEC-005; o sistema de combustível aplica a penalidade uma única vez por evento recebido e não reimplementa detecção.
- **Vida útil e estados**: a inicialização é chamada na largada; a orquestração de reinício, pausa, vitória, progressão e Game Over cabe à SPEC-008, futura. A atualização do consumo progride enquanto a corrida estiver ativa (a integração com pausa/estados segue a mesma SPEC-008). **A entrega escalonada — 007 emite `fuel_depleted`, 008 transita para GAME_OVER — está amparada pela emenda constitucional v3.0.0 (2026-10-10) e registrada no `plan.md` desta feature (Constitution Check + Complexity Tracking).**
- **Escopo da constituição (§Comportamento de Colisão)**: "consumir combustível adicional" da colisão refere-se ao veículo do jogador — único com combustível —, implementado como penalidade pequena e configurável nos ambientes avançados, coerente com §Veículo do Jogador (recursos limitados) e §Configuração (valores centralizados). A penalidade igual a zero em planície e deserto e o mecanismo que cobre os quatro ambientes estão cobertos pela emenda constitucional v3.0.0 (2026-10-10, §Comportamento de Colisão) e registrados no `plan.md` desta feature (Constitution Check e Complexity Tracking).
- **Testes obrigatórios**: o texto-fonte exige explicitamente a implementação de testes para os 27 cenários da seção "Testes obrigatórios" — **cobertos pelas** Acceptance Scenarios (os 27 testes do texto-fonte não correspondem 1 a 1 aos 31 cenários): US1 = testes 1–10 (10 cenários); US2 = testes 16–25 (10 cenários); US3 = testes 11–14 (**5 cenários** — o AS5, "nenhuma tela de Game Over e velocidade inalterada", é garantido pelas asserções de FR-021 em T010 e pelo passo 8 do quickstart); US4 = testes 15 e 26 (**4 cenários** — AS2/AS3/AS4 cobertos pelo teste 26 via regras H1–H5 do HUD); US5 = teste 27 (**2 cenários** — AS2 validada na calibração da tarefa T018). A exigência de testes fica registrada aqui para que o plano de tarefas os inclua.
- **Cobertura das 28 regras de gameplay do texto-fonte**: todas repercutem em FRs — 1/2 → FR-001/FR-002; 3 → FR-010; 4/5 → FR-005; 6 → FR-006; 7/8 → FR-008; 9 → FR-009; 10/11 → FR-018/FR-019; 12 → FR-021; 13/14 → FR-011; 15/16 → FR-011/FR-027; 17 → FR-011; 18 → FR-014; 19 → FR-013; 20 → FR-015; 21 → FR-017; 22 → FR-012; 23 → FR-018; 24 → FR-024; 25 → FR-022/FR-023; 26 → FR-021/FR-030; 27 → FR-026; 28 → FR-033.
- **Escopo de apresentação (decidido nas Clarifications de 2026-10-09)**: indicador visual mínimo — barra de combustível na partida e sinalização de combustível baixo composta por mudança de cor da barra e rótulo/ícone estático ao lado (ex.: "BAIXO"), mantidos enquanto durar a condição —, sem sons, animações ou efeitos avançados. Sendo o primeiro elemento de interface do projeto, as cores exatas, o posicionamento e o estilo pixel-art do indicador são definidos no planejamento, respeitando as regras de apresentação da constituição.

## Out of Scope

Os itens a seguir estão explicitamente fora do escopo desta especificação e não devem ser implementados:

- Menu inicial.
- Seleção do carro azul ou vermelho.
- Postos de combustível.
- Reabastecimento durante a corrida.
- Combustíveis especiais.
- Melhorias ou modificações no motor.
- Alteração da velocidade máxima em função do combustível.
- Modificações físicas no veículo do jogador.
- Implementação da vitória.
- Implementação do Game Over.
- Progressão de distância da pista.
- Pontuação.
- Sons, animações e efeitos visuais avançados (o indicador mínimo do FR-025 — barra e sinalização de baixo — permanece sem efeitos adicionais).

Essas funcionalidades poderão ser definidas em especificações posteriores, quando aplicável.
