# Feature Specification: Progressão da Pista, Estados do Jogo, Combustível e Itens Coletáveis

**Feature Branch**: `008-track-progression-fuel-cans`

**Created**: 2026-10-10

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-008 — Progressão da Pista, Estados do Jogo, Combustível e Itens Coletáveis" (gerenciamento dos estados do jogo e menu inicial com seleção de veículo; marcações visuais de início e chegada no mundo da pista; progressão da pista e controle da distância percorrida; indicador de progresso na interface; dimensionamento do combustível pela distância total; desaceleração por falta de combustível, vitória e Game Over; pausa, reinício e retorno ao menu; galões de gasolina coletáveis com geração balanceada pela dificuldade do ambiente — integrando e preservando as SPEC-001 a SPEC-007).

## Clarifications

### Session 2026-10-10

- Q: Quando a distância total da corrida é alterada, o combustível da partida deve ser recalculado automaticamente a partir da fórmula (distância × consumo por unidade + margem), ou a fórmula serve apenas para calibrar valores fixos no planejamento? → A: **Capacidade derivada em tempo de execução** — a capacidade do tanque e a quantidade inicial são calculadas a cada corrida a partir de `distância total × consumo base por unidade de distância + margem`; alterar a distância total muda o tanque automaticamente.
- Q: Após coletar um galão que restaura o combustível, o que deve acontecer com o sinal único de esgotamento e com o bloqueio de aceleração para o caso de o combustível zerar de novo na mesma corrida? → A: **Sem rearme** — o evento de esgotamento permanece único por corrida (semântica da SPEC-007 preservada); o bloqueio de aceleração e a transição para `GAME_OVER` derivam do valor atual de combustível (zero = sem aceleração; parado com zero e sem concluir = `GAME_OVER`).
- Q: Além de retomar a corrida, a tela de pausa deve oferecer quais opções ao jogador? → A: **Continuar + Reiniciar + Voltar ao menu** — mesmos rótulos e fluxos das telas de vitória e Game Over.
- Q: O galão possui velocidade própria ou acompanha a rolagem da pista? → A: **Sem velocidade própria** — o galão só se desloca com a rolagem, impulsionada pela velocidade do jogador: com o jogador parado o galão fica parado; quando o jogador volta a se mover, ele retoma o percurso de cima para baixo.
- Q: O que acontece com um galão que o jogador não consegue interagir (passa por ele)? → A: **Reciclagem obrigatória** — ao atingir o final (base) da tela sem coleta, ele é limpo do jogo e devolvido ao controle de apresentação (pool do gerenciador de itens) para ser apresentado novamente mais adiante na corrida, em nova posição válida.
- Q: A interação com o galão dispara o comportamento de colisão do jogo? → A: **Não** — a coleta não é colisão: nenhuma perda de velocidade, deriva, penalidade de combustível, cooldown ou evento de colisão; o contato vale apenas como coleta.
- Q: O galão pode ser posicionado sobre NPCs? → A: **Não** — o posicionamento deve garantir espaço em relação aos NPCs para que o jogador consiga interagir com o galão sem provocar uma colisão com eles.
- Q: O que os parâmetros `fuel_can_min_per_race` e `fuel_can_max_per_race` devem limitar exatamente — o total de galões gerados em toda a corrida ou a quantidade de galões ativos na tela ao mesmo tempo? → A: **Total acumulado da corrida** — piso: a corrida apresenta ao menos N galões do início ao fim; teto: no máximo N galões são gerados em toda a corrida; a quantidade simultânea continua coberta por `fuel_can_max_active` e pelo piso de disponibilidade.
- Q: Ao mudar apenas de faixa (movimento lateral, sem avançar pela pista), a distância percorrida deve crescer ou permanecer inalterada? → A: **Não cresce** — só a velocidade que impulsiona a rolagem (avanço pela pista) acumula distância; trocar de faixa sozinha soma zero.
- Q: A quantidade de combustível restaurada por galão (`fuel_can_restore_amount`) deve ser um único valor global para todas as corridas e ambientes, ou deve variar por ambiente? → A: **Um único valor global** — todos os galões, em qualquer ambiente, restauram a mesma quantidade configurada; a dificuldade varia pela frequência de geração, não pela quantidade por item.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Iniciar, pausar e encerrar corridas pelo menu (Priority: P1)

O jogo abre no menu inicial, onde o jogador escolhe entre o veículo azul e o vermelho (padrão: azul) e inicia uma corrida. Ao iniciar, todos os sistemas são preparados do zero para aquela corrida. Durante a corrida, o jogador pode pausar e retomar sem que nada continue avançando em segundo plano. Ao final, o jogador escolhe tentar novamente ou voltar ao menu, e o menu nunca deixa gameplay rodando em segundo plano.

**Why this priority**: É o arco completo da sessão de jogo e o que dá sentido aos estados `MENU`, `READY`, `PLAYING`, `PAUSED`, `VICTORY` e `GAME_OVER`. Sem um ciclo de partida funcional e centralizado, nenhuma das demais mecânicas (distância, vitória, Game Over, galões) tem um início e um fim confiáveis. É o MVP: sozinho já permite rodar o jogo de ponta a ponta.

**Independent Test**: Abrir o jogo e conferir que começa no menu; selecionar cada veículo e conferir que a escolha é refletida sem mudar atributos de gameplay; iniciar uma corrida e conferir que todos os sistemas reiniciam do zero; pausar e conferir que nada avança; retomar e conferir continuidade sem saltos; encerrar e conferir reinício/menu sem resíduos.

**Acceptance Scenarios**:

1. **Given** o jogo recém-aberto, **When** a tela é apresentada, **Then** o estado é `MENU`, o menu exibe a opção de iniciar a corrida e a seleção entre o veículo azul e o vermelho, e nenhum sistema de gameplay está avançando.
2. **Given** o menu sem escolha explícita, **When** o jogador inicia a corrida, **Then** o veículo azul é o selecionado por padrão.
3. **Given** o veículo vermelho selecionado, **When** a corrida inicia, **Then** os atributos de gameplay (velocidade, aceleração, frenagem, limites, hitbox e dimensões) são exatamente os mesmos do veículo azul.
4. **Given** uma corrida em andamento ou encerrada anteriormente, **When** o jogador inicia uma nova corrida, **Then** distância e progresso, combustível e estado de esgotamento, velocidade e controles, NPCs, efeitos de colisão e deriva, temporizadores, estado de fim, marcadores de início e chegada e galões são reinicializados uma única vez, sem instâncias duplicadas nem conexões de eventos repetidas.
5. **Given** uma corrida em `PLAYING`, **When** o jogador pausa, **Then** o estado passa a `PAUSED` e ficam interrompidos: movimento do jogador, consumo de combustível, progressão da distância, movimento e atualização dos NPCs, movimento e geração dos galões, temporizadores de gameplay, efeitos de deriva e colisão e a verificação de chegada.
6. **Given** uma corrida em `PAUSED`, **When** o jogador retoma, **Then** o estado volta a `PLAYING` e os sistemas continuam exatamente de onde pararam, sem consumo nem deslocamento acumulado durante a pausa.
7. **Given** uma corrida encerrada, **When** o jogador escolhe "Tentar novamente", **Then** uma nova corrida começa limpa, sem resíduos da anterior.
8. **Given** uma corrida encerrada ou pausada (a pausa oferece a opção), **When** o jogador escolhe "Voltar ao menu", **Then** o estado volta a `MENU` e nenhum sistema de gameplay continua avançando em segundo plano.
9. **Given** uma corrida em `PAUSED`, **When** o jogador observa as opções da tela de pausa, **Then** "Continuar", "Reiniciar" e "Voltar ao menu" estão disponíveis.

---

### User Story 2 - Percorrer a distância da pista com início e chegada visíveis (Priority: P1)

A corrida tem uma distância total configurável. Enquanto o jogador dirige, a distância percorrida cresce exatamente no ritmo do avanço efetivo pela pista (o mesmo que impulsiona a rolagem) — parado não cresce, pausada não cresce, trocar de faixa sem avançar não cresce — e a interface mostra o progresso (percorrida, total e barra percentual). Uma marcação de `INÍCIO` fica no ponto de partida e se desloca para baixo conforme a rolagem até sumir da tela; uma marcação de `CHEGADA` está no fim lógico da pista e se aproxima conforme o progresso avança.

**Why this priority**: Sem distância e sem os marcadores não existe corrida finita, nem vitória, nem dimensionamento de combustível, nem base para distribuir galões. É o segundo pilar do jogo depois do ciclo de estados.

**Independent Test**: Acelerar e medir o crescimento da distância; parar e confirmar estagnação; pausar/retomar sem salto; conferir que o indicador exibe valores coerentes com a medição; observar a marcação de início sumir da tela e não voltar; observar a chegada aproximar-se conforme o progresso.

**Acceptance Scenarios**:

1. **Given** uma corrida iniciada, **When** o jogador acelera e o veículo avança pela pista, **Then** a distância percorrida aumenta em função do componente de avanço (o mesmo que impulsiona a rolagem) e do tempo decorrido; mudança de faixa sem avançar soma zero.
2. **Given** o veículo parado, **When** o tempo passa em `PLAYING`, **Then** a distância percorrida permanece inalterada.
3. **Given** a corrida pausada, **When** permanece pausada e depois é retomada, **Then** a distância não muda durante a pausa e não ocorre salto de progressão ao retomar.
4. **Given** segmentos de estrada reciclados durante a corrida, **When** a reciclagem ocorre, **Then** a distância percorrida não é reiniciada nem incrementada artificialmente.
5. **Given** a distância percorrida próxima do total, **When** o valor chegaria ao total, **Then** ele é limitado ao total configurado — nunca o ultrapassa.
6. **Given** uma corrida em andamento, **When** o jogador observa a interface, **Then** o indicador mostra distância percorrida, distância total e barra de progresso percentual coerentes com o progresso real.
7. **Given** a marcação de início no ponto de partida, **When** o jogador ainda está parado, **Then** a marcação permanece na posição inicial.
8. **Given** o jogador avançando, **When** a rolagem da pista acontece, **Then** a marcação de início se desloca visualmente para baixo com a mesma lógica da rolagem e, ao sair completamente da área visível, é removida ou desativada e não reaparece durante a mesma corrida.
9. **Given** a marcação de chegada posicionada no fim lógico da pista, **When** o progresso avança, **Then** ela se aproxima visualmente do jogador segundo a mesma lógica de progressão da estrada.
10. **Given** a marcação de início já fora da tela em uma nova corrida, **When** a corrida é reiniciada, **Then** a marcação volta a ser exibida na posição inicial da nova corrida.

---

### User Story 3 - Vencer ao cruzar a linha de chegada com combustível (Priority: P1)

Quando o jogador atravessa completamente a linha de chegada com combustível disponível e a corrida ainda está ativa, a corrida é vencida: o jogo entra em `VICTORY`, a progressão e o consumo param, o gameplay encerra e a tela de vitória é apresentada — exatamente uma vez por corrida.

**Why this priority**: É o objetivo final do jogo (chegar ao final antes de ficar sem combustível). Depende da progressão da US2 e do combustível já existente.

**Independent Test**: Aproximar a chegada e conferir que ela se manifesta conforme o progresso; cruzar a linha com combustível e conferir `VICTORY` uma única vez; tentar vencer em outras condições (sem combustível, fora de `PLAYING`) e conferir que a vitória não ocorre.

**Acceptance Scenarios**:

1. **Given** o jogo em `PLAYING` com combustível disponível, **When** o jogador cruza completamente a linha de chegada, **Then** o estado muda para `VICTORY`, a progressão da distância e o consumo de combustível se interrompem, o gameplay encerra e a tela de vitória é apresentada.
2. **Given** o combustível esgotado, **When** o movimento residual leva o veículo além da linha, **Then** a vitória não ocorre — a corrida está perdida.
3. **Given** o jogo fora de `PLAYING` (pausado ou já encerrado), **When** qualquer condição de cruzamento se daria, **Then** a vitória não é avaliada nem ocorre.
4. **Given** uma corrida vencida, **When** o tempo continua, **Then** exatamente um evento de vitória foi emitido — nunca um por quadro.
5. **Given** a tela de vitória, **When** o jogador observa as opções, **Then** "Tentar novamente" e "Voltar ao menu" estão disponíveis.

---

### User Story 4 - Sofrer a falta de combustível até a parada e o Game Over (Priority: P1)

Quando o combustível zera, o FuelSystem avisa uma única vez, o jogador não consegue mais iniciar acelerações e o veículo desacelera gradualmente até parar — sem cortar o movimento na hora. Enquanto houver deslocamento, a distância continua a crescer e a corrida segue ativa, permitindo que um galão coletado durante a desaceleração restaure o combustível e devolva a possibilidade de acelerar. Se o veículo parar antes de concluir a corrida, o jogo vai para `GAME_OVER`, uma única vez.

**Why this priority**: Concretiza a regra central "chegar antes de ficar sem combustível" e conclui a entrega escalonada prevista pela emenda constitucional v3.0.0 (SPEC-007 emite o esgotamento; esta spec faz a transição de estado).

**Independent Test**: Zerar o combustível e conferir o aviso único, a impossibilidade de acelerar e a desaceleração gradual; confirmar distância ainda crescendo durante a desaceleração; confirmar parada → `GAME_OVER` uma única vez; repetir sem coletar e com coletar um galão durante a desaceleração.

**Acceptance Scenarios**:

1. **Given** o combustível chegando a zero, **When** a quantidade atinge zero, **Then** o sistema de combustível emite exatamente um evento de esgotamento (o único da corrida) e o jogador não consegue iniciar novas acelerações enquanto o combustível atual for zero.
2. **Given** o tanque esgotado com o veículo em movimento, **When** o tempo passa, **Then** o veículo desacelera gradualmente até atingir velocidade zero — não para instantaneamente — e não recuper velocidade enquanto não houver combustível.
3. **Given** a desaceleração em andamento, **When** ainda há deslocamento efetivo, **Then** a distância percorrida continua a aumentar e a corrida permanece em `PLAYING`.
4. **Given** o esgotamento ocorrendo antes da conclusão, **When** o veículo para com o combustível atual em zero, **Then** o estado muda para `GAME_OVER`, a corrida é considerada perdida mesmo que o movimento residual tenha levado o veículo visualmente além da linha, e exatamente um evento de Game Over é emitido.
5. **Given** o combustível zerado com o veículo ainda em movimento, **When** o jogador coleta um galão antes da parada completa, **Then** o combustível é restaurado pelo sistema de combustível e, permanecendo o jogo em `PLAYING` com a corrida não encerrada, voltar a acelerar volta a ser permitido — o bloqueio deriva do valor atual de combustível, não de um evento travado.
6. **Given** o jogo já em `GAME_OVER`, **When** um galão é coletado (ou tentado ser coletado), **Then** a corrida não é reativada nem retorna a `PLAYING`.
7. **Given** uma corrida encerrada por esgotamento, **When** o tempo continua, **Then** nenhum evento adicional de Game Over é emitido.

---

### User Story 5 - Dimensionar o combustível pela distância total (Priority: P1)

A distância total da corrida é usada para estimar quanto combustível é necessário: consome-se por unidade de distância segundo o modelo já existente, mais uma margem de segurança configurável. A capacidade do tanque e a quantidade inicial de cada corrida são calculadas no início da corrida a partir dessa estimativa. O resultado permite concluir uma corrida normal com folga, mesmo considerando penalidades de colisão e oportunidades de coleta, e não é reforçado automaticamente durante a corrida — a recuperação em curso de prova vem só dos galões.

**Why this priority**: É o elo entre a nova distância (US2) e o combustível já existente (SPEC-007) e o que torna o balanceamento coerente com o tamanho da pista. Sem isso, ou a corrida é impossível, ou o combustível é irrelevante.

**Independent Test**: Alterar a distância total e conferir que a estimativa de combustível muda proporcionalmente; rodar uma corrida de referência e conferir que ela é concluível; conferir que nada aumenta o combustível automaticamente em curso de prova.

**Acceptance Scenarios**:

1. **Given** a distância total configurada, **When** a corrida é preparada, **Then** a capacidade do tanque e a quantidade inicial da corrida são calculadas a partir da distância total, do consumo base por unidade de distância e da margem de segurança, todos centralizados na configuração.
2. **Given** uma corrida de referência sem colisões nem coletas, **When** ela é executada até o fim, **Then** ela é concluída com combustível suficiente — a sobra final fica dentro da faixa de calibração definida para o balanceamento.
3. **Given** penalidades de colisão e oportunidades de coleta ocorrendo, **When** a corrida é concluída, **Then** o dimensionamento ainda permite vencer uma corrida normal com folga.
4. **Given** uma corrida em andamento, **When** o consumo real ocorre, **Then** nenhum sistema aumenta o combustível automaticamente para compensá-lo — as únicas recuperações em curso de prova vêm da coleta de galões.
5. **Given** a distância total alterada apenas por configuração, **When** a corrida inicia, **Then** a capacidade derivada e a quantidade inicial acompanham o novo valor automaticamente, sem alteração da lógica e sem segunda origem de valores.

---

### User Story 6 - Coletar galões de gasolina na pista (Priority: P2)

Ao longo da pista aparecem galões de gasolina sobre a superfície dirigível da estrada. Eles não têm velocidade própria: se deslocam apenas com a rolagem, que é impulsionada pela velocidade do jogador — parado, o galão fica parado; quando o jogador se move de novo, ele retoma o percurso de cima para baixo. Ao encostar em um galão, ele desaparece na hora (sem nenhum efeito de colisão), o combustível sobe imediatamente (sem passar do máximo do tanque) e o mesmo galão não pode ser coletado duas vezes. Se o jogador passa por ele, o galão que chega à base da tela é limpo e devolvido ao pool para ser apresentado novamente mais adiante. O jogador consegue usar a coleta para se recuperar, inclusive durante a desaceleração por falta de combustível.

**Why this priority**: Dá ao jogador uma segunda forma de administrar o combustível além de dirigir devagar, e é o que permite manter os ambientes difíceis concluíveis. Depende do combustível (SPEC-007), da pista (US2) e do encerramento (US4).

**Independent Test**: Gerar um galão numa posição alcançável, colidir com ele e conferir sumiço imediato, aumento imediato do combustível, cap de capacidade, impossibilidade de coleta dupla e atualização do medidor.

**Acceptance Scenarios**:

1. **Given** uma corrida ativa, **When** um galão é gerado, **Then** ele aparece sobre a superfície dirigível da pista, dentro dos limites válidos da estrada (incluindo transições entre duas e quatro vias), em posição alcançável pelo jogador e sem sobreposição inadequada com NPCs, marcadores ou outros itens.
2. **Given** o galão na pista, **When** a corrida progride ou o jogador permanece parado, **Then** ele se desloca apenas com a rolagem impulsionada pela velocidade do jogador — parado no local enquanto o jogador está parado, sem velocidade própria —, retomando o percurso de cima para baixo quando o jogador volta a se mover, e não fica fixo na interface.
3. **Given** o jogador sobre o galão com o jogo em `PLAYING`, **When** as áreas se sobrepõem, **Then** o galão é marcado como coletado, é desativado ou removido do mundo da pista e a coleta acontece exatamente uma vez, mesmo com sobreposição durando vários quadros.
4. **Given** a coleta validada, **When** ela é processada, **Then** o combustível é restaurado pela quantidade configurada por meio da interface pública do sistema de combustível, o medidor acompanha no mesmo instante e um evento de coleta é emitido uma única vez.
5. **Given** um tanque na capacidade máxima, **When** um galão é coletado, **Then** o galão desaparece normalmente e o combustível permanece exatamente na capacidade — nunca a ultrapassa.
6. **Given** qualquer saldo, **When** a coleta é aplicada, **Then** o resultado é `min(atual + recuperado, capacidade)`, nunca negativo nem inválido, e a capacidade máxima do tanque não é alterada.
7. **Given** o jogo fora de `PLAYING`, **When** ocorre contato com um galão, **Then** a coleta não é confirmada.
8. **Given** um galão coletado, **When** a mesma corrida continua, **Then** ele não reaparece naquela posição nem volta a ser coletável; se a instância for reutilizada pelo pool, ela entra como item novo em nova posição válida, com estado de coletado redefinido.
9. **Given** o jogador coletando um galão, **When** o contato ocorre, **Then** nenhuma consequência de colisão é produzida — sem perda de velocidade, sem deriva, sem penalidade de combustível, sem cooldown e sem evento de colisão; o contato vale apenas como coleta.
10. **Given** um galão não coletado que atinge a base da tela, **When** ele sai completamente da área de jogo, **Then** ele é limpo do jogo, devolvido ao pool do gerenciador de itens e pode ser apresentado novamente mais adiante na mesma corrida, em nova posição válida — dando nova oportunidade de interação.

---

### User Story 7 - Variar a disponibilidade de galões pela dificuldade (Priority: P2)

A frequência dos galões respeita a dificuldade do ambiente: mais galões em planície e deserto, menos em floresta e gelo. A distribuição considera a distância total, a distância já percorrida e a distância desde a última geração, com limites mínimos e máximos, espaçamento entre itens, em relação aos NPCs e em relação ao início e à chegada. A diferença entre ambientes é perceptível, mas nenhum ambiente fica impossível de concluir.

**Why this priority**: É o balanceamento da mecânica da US6 — sem ele a coleta existe, mas não contribui para a progressão de dificuldade. Depende da US6 e da dificuldade já existente (SPEC-003).

**Independent Test**: Rodar corridas nos quatro ambientes e comparar a distribuição; conferir limites, espaçamentos, distância mínima do início/chegada e ausência de locais inalcançáveis.

**Acceptance Scenarios**:

1. **Given** os quatro ambientes com suas configurações, **When** se compara a frequência esperada de galões, **Then** planície oferece a maior disponibilidade relativa, deserto é moderada, floresta é reduzida e gelo é a mais restrita, segundo a configuração.
2. **Given** a geração baseada em distância, **When** corridas diferentes percorrem a mesma distância em velocidades diferentes, **Then** a distribuição é consistente — a geração não depende exclusivamente de temporizadores.
3. **Given** galões ativos, **When** se avalia a quantidade simultânea, **Then** o limite máximo configurado (`fuel_can_max_active`) é respeitado em todo momento, e existe um piso configurado de disponibilidade para evitar ausências prolongadas de itens; ao longo da corrida, o piso e o teto do total gerado por corrida também são respeitados — ao menos N galões apresentados do início ao fim e no máximo N gerados na corrida inteira.
4. **Given** um novo ponto de geração, **When** ele é avaliado, **Then** ele respeita o espaçamento mínimo em relação aos itens ativos, nunca é posicionado sobre um NPC e fica em posição que permite ao jogador interagir sem provocar colisão com NPCs, respeita o espaçamento em relação ao início e à chegada, e pertence a uma posição válida da pista.
5. **Given** uma posição candidata inválida, **When** ela é avaliada, **Then** o sistema busca outra posição ou adia a geração — nunca confirma uma posição inválida.
6. **Given** um ambiente difícil, **When** a distribuição é calibrada, **Then** a corrida permanece viável: o combustível inicial e a distribuição de galões continuam permitindo concluir a pista.
7. **Given** o jogo fora de `PLAYING`, **When** a geração seria considerada, **Then** nenhum novo galão é criado.

---

### User Story 8 - Ajustar o balanceamento só pela configuração (Priority: P3)

Todos os parâmetros novos — distância total, consumo base por unidade de distância, margem de segurança, quantidade restaurada por galão, frequência e limites de geração por ambiente, espaçamentos — ficam centralizados na configuração, para que o ajuste não exija mexer na lógica.

**Why this priority**: O balanceamento será iterativo várias vezes depois da implementar; deixá-lo espalhado pelo código multiplicaria retrabalho. Importante, porém dependente de todo o resto.

**Independent Test**: Alterar cada parâmetro apenas pela configuração e observar o efeito correspondente; conferir que nenhum teste anterior quebra e que nenhum arquivo de lógica precisou mudar.

**Acceptance Scenarios**:

1. **Given** os parâmetros centralizados na configuração, **When** cada um deles é alterado, **Then** o efeito correspondente aparece no jogo sem alteração da lógica central.
2. **Given** valores de balanceamento no código-fonte da lógica, **When** se revisa a implementação, **Then** não há valores mágicos espalhados — cada parâmetro tem uma única origem configurável.

---

### Edge Cases

- Esgotamento e cruzamento da chegada no mesmo quadro: a precedência é do esgotamento — sem combustível disponível não há vitória.
- Esgotamento logo após a linha, mas com combustível no momento do cruzamento: a vitória vale (as condições são avaliadas no instante do cruzamento completo).
- Movimento residual após o esgotamento leva o veículo além da linha: a corrida continua perdida e termina em `GAME_OVER` na parada.
- Coleta de galão no mesmo quadro em que o combustível zera: a ordem de atualização é única e consistente (detecção → coleta → combustível → transição de estado); coleta válida em `PLAYING` restaura e mantém a corrida ativa.
- Coleta de galão no mesmo quadro da parada completa: se a transição para `GAME_OVER` já ocorreu, a coleta não reativa a corrida.
- Segundo esgotamento na mesma corrida, depois de uma coleta: o bloqueio de aceleração volta a valer pelo valor zero do combustível e o veículo desacelera de novo; o evento de esgotamento não se repete — permanece único por corrida, sem rearme.
- Tanque cheio ao coletar: o galão desaparece e o valor permanece na capacidade.
- Jogador parado com galão na tela: o galão permanece parado (não tem velocidade própria) até o jogador se mover de novo; a coleta continua possível enquanto ele estiver parado.
- Galão não coletado que atinge a base da tela: limpo do jogo e devolvido ao pool do gerenciador de itens; pode ser apresentado novamente mais adiante na mesma corrida, em nova posição válida — nada fica acumulado fora da tela.
- Reutilização de pool: um galão reciclado nunca reaparece com estado de coletado herdado nem com referências de colisão da posição anterior.
- Coleta no mesmo quadro de uma colisão com NPC: os sistemas permanecem independentes — a coleta não produz nem recebe consequência de colisão.
- Sobreposição com o mesmo galão por vários quadros: uma única coleta, um único evento.
- Reciclagem de segmentos da estrada: galões coletados não reaparecem e a distância não é alterada.
- Distância atingindo o total antes da linha ser cruzada por completo: a distância é limitada ao total e a vitória depende do cruzamento efetivo, não apenas do valor.
- Reinício durante `READY`, `PAUSED`, `VICTORY` ou `GAME_OVER`: a nova corrida nasce limpa em qualquer estado.
- Voltar ao menu com galões visíveis e com a corrida em andamento: tudo é removido e nenhum sistema continua avançando.
- Pausa com marcadores ou galões na tela: ao retomar, as posições são as mesmas da pausa, sem deslocamento acumulado.
- Transição entre pistas de duas e quatro vias com marcadores ou galões na área: o posicionamento continua válido na geometria vigente.
- Mudança de ambiente em runtime já suportada pelo jogo: a configuração de geração passa a valer para as próximas gerações, sem retroatividade.
- Reinício imediatamente após uma corrida com eventos pendentes: nenhum evento da corrida anterior vaza para a nova.
- Erro de configuração (distância total zero ou negativa): tratado por limites válidos, sem divisão por zero na estimativa nem conclusão instantânea; a capacidade derivada é limitada aos limites válidos do sistema de combustível.
- Teto de galões por corrida (`fuel_can_max_per_race`) atingido: nenhuma nova geração ocorre até o fim da corrida; a reciclagem de galões não coletados que saem da tela continua válida e não conta como nova geração.
- Mudança de faixa sem avançar pela pista: 0 acréscimo de distância — só o componente de avanço (rolagem) acumula.
- Interface desconectada dos dados (ausência de camada de UI em testes): os sistemas continuam funcionando e a ausência de interface não quebra a corrida.

## Requirements *(mandatory)*

### Functional Requirements

**Estados do jogo, menu e ciclo de corrida**

- **FR-001**: O jogo deve representar explicitamente os estados `MENU`, `READY`, `PLAYING`, `PAUSED`, `VICTORY` e `GAME_OVER`, começar em `MENU`, e ter todas as transições centralizadas em um único sistema de estado de jogo (o `GameManager` já previsto na constituição — nome de referência, adaptável à convenção do código); objetos individuais de gameplay não podem decidir o estado global por conta própria.
- **FR-002**: O menu deve permitir iniciar uma nova corrida e selecionar o veículo azul ou o vermelho pelos assets existentes `assets/player/azul/azul.png` e `assets/player/vermelho/vermelho.png`; o azul é a seleção padrão; a escolha não altera nenhum atributo de gameplay e não modifica dimensões visuais nem hitboxes dos veículos.
- **FR-003**: Iniciar uma corrida deve reinicializar, uma única vez e sem duplicar instâncias nem conexões de eventos: distância percorrida e progresso da pista; combustível e estado de esgotamento; velocidade e controles do jogador; NPCs e estados temporários; efeitos de colisão e deriva; temporizadores; estado de vitória ou derrota; marcadores de início e chegada; galões da corrida anterior e o controle de geração de novos galões.
- **FR-004**: Durante `PAUSED` devem ficar interrompidos: movimento do jogador, consumo de combustível, progressão da distância, movimento e atualização dos NPCs, movimento e geração dos galões, temporizadores de gameplay, efeitos de deriva e colisão e a verificação de chegada; ao retomar, os sistemas continuam do estado anterior, sem consumo ou deslocamento acumulado.
- **FR-005**: A interface deve ser uma observadora dos sistemas: ela não calcula distância nem combustível de forma independente e não controla a física do veículo.

**Distância e progressão da pista**

- **FR-006**: O sistema de progressão da pista (o `TrackManager` previsto na constituição — nome de referência) deve manter: distância total, distância percorrida, distância restante, percentual de progresso, estado de conclusão e posição lógica da linha de chegada.
- **FR-007**: A distância deve ser acumulada com base na velocidade efetiva do veículo e no tempo decorrido, em unidades consistentes — a velocidade efetiva é **apenas o componente de avanço pela pista, o mesmo que impulsiona a rolagem**: mudança de faixa sem avançar soma zero —; veículo parado não acumula; estar em `PLAYING` por si só não acumula; a posição vertical do sprite não é usada como distância; reciclar segmentos da estrada não reinicia nem incrementa artificialmente a distância; a pausa interrompe a progressão; o valor nunca ultrapassa o total configurado; e as transições entre pistas de duas e quatro vias continuam corretas.
- **FR-008**: A distância total deve ser configurável, sem alteração da lógica.
- **FR-009**: A interface deve apresentar um indicador de distância consistente com o medidor de combustível, mostrando distância percorrida, distância total e barra de progresso percentual (formato de referência: `Distância: 2,4 km / 5,0 km`; a distância restante é opcional); os dados vêm do sistema de progressão da pista, a pausa congela o indicador e o reinício o retorna a zero.

**Marcações de início e chegada**

- **FR-010**: Deve existir uma marcação de início no mundo da pista, com o texto `INÍCIO` e uma faixa quadriculada (ou elemento equivalente) representando a linha de partida; ela permanece na posição inicial enquanto o jogador está parado, desloca-se para baixo com a lógica de rolagem existente quando o jogador avança e, ao sair completamente da área visível, é removida ou desativada sem reaparecer na mesma corrida.
- **FR-011**: Deve existir uma marcação de chegada posicionada no final lógico da pista, com o texto `CHEGADA` e uma faixa quadriculada representando a linha de chegada, que se aproxima visualmente conforme o progresso avança, usando a mesma lógica de progressão da estrada.
- **FR-012**: Ambas as marcações pertencem ao mundo da pista e à lógica de rolagem — não à interface fixa.

**Vitória**

- **FR-013**: A vitória ocorre somente quando as quatro condições se dão juntas: o jogo está em `PLAYING`; há combustível disponível; o jogador cruza completamente a linha de chegada; e a corrida não foi encerrada anteriormente.
- **FR-014**: Ao vencer, o jogo entra em `VICTORY`, interrompe a progressão da distância e o consumo de combustível, encerra o gameplay e apresenta a tela de vitória; o evento de vitória ocorre exatamente uma vez por corrida.

**Esgotamento do combustível, desaceleração e Game Over**

- **FR-015**: Ao chegar a zero, o sistema de combustível emite o evento único de esgotamento da corrida (já previsto na SPEC-007, rearmed somente em nova corrida); a partir daí o bloqueio de novas acelerações é determinado pelo valor atual de combustível — zero impede acelerar, valor restaurado reabilita —; o veículo desacelera gradualmente até velocidade zero — não para instantaneamente —, não recupera velocidade enquanto o valor atual for zero, a distância continua a aumentar enquanto houver deslocamento efetivo e a corrida permanece em `PLAYING` durante toda a desaceleração.
- **FR-016**: Se o combustível se esgotar antes da conclusão, a corrida está perdida mesmo que o movimento residual leve o veículo visualmente além da linha; quando o veículo para com o combustível atual em zero e a corrida não concluída, o sistema de estados transita para `GAME_OVER` e o evento de Game Over ocorre exatamente uma vez por corrida.
- **FR-017**: A coleta de um galão durante a desaceleração deve restaurar o combustível pelo sistema de combustível e só reabilita novas acelerações se o jogo ainda estiver em `PLAYING` com a corrida não encerrada; se o estado já for `GAME_OVER`, a coleta não reativa a corrida; a ordem de atualização entre colisões, coleta de itens, combustível e transições de estado deve ser única e consistente.

**Dimensionamento do combustível pela distância**

- **FR-018**: A distância total deve ser usada para estimar o combustível necessário, segundo a referência `combustivel_estimado = distancia_total × consumo_base_por_unidade_de_distancia`, acrescida de uma margem de segurança configurável; a capacidade do tanque e a quantidade inicial de cada corrida devem ser derivadas, no início da corrida, dessa estimativa (capacidade = quantidade inicial = combustível estimado, com a partida nascendo cheia, conforme a SPEC-007) — alterar a distância total muda o tanque automaticamente, sem dupla fonte de verdade; os parâmetros (consumo esperado por unidade de distância, parâmetros de consumo adicionais e margem) ficam centralizados na configuração e os limites válidos do sistema de combustível continuam valendo.
- **FR-019**: A estimativa deve respeitar as unidades e o modelo de consumo existente (calculado por tempo e velocidade): havendo divergência, adapta-se ao modelo sem substituí-lo — mantém-se o cálculo de consumo vigente da SPEC-007.
- **FR-020**: O balanceamento deve permitir concluir uma corrida normal com combustível suficiente, considerando penalidades de colisão e oportunidades de coleta, e nenhum sistema pode aumentar automaticamente o combustível durante a corrida para compensar o consumo real — as recuperações em prova vêm exclusivamente dos galões.

**Galões de gasolina — asset e posicionamento**

- **FR-021**: Os galões devem usar o asset `gasolina.png`, de 32 × 51 pixels, sem redesenho nem alteração desnecessária das dimensões originais; o caminho do arquivo segue a organização existente de assets (o arquivo já existe no projeto, em `assets/decoracao/gasolina.png`) e a escala de exibição respeita o padrão de pixel art do jogo, sem suavização que prejudique o sprite.
- **FR-022**: Os galões devem ser posicionados sobre a superfície dirigível da estrada, dentro dos limites válidos (considerando as transições entre duas e quatro vias), em posições alcançáveis pelo jogador, fora de locais ocultos ou impossíveis, sem sobreposição inadequada com marcadores de início e chegada ou outros itens, nunca posicionados sobre um NPC — o posicionamento deve garantir espaço em relação aos NPCs de modo que o jogador consiga interagir com o galão sem provocar uma colisão com NPCs — e sem criar colisões inevitáveis.
- **FR-023**: O galão faz parte do mundo da pista e não possui velocidade própria: desloca-se apenas com a rolagem da estrada, que é impulsionada pela velocidade do jogador — com o jogador parado o galão fica parado, e quando o jogador volta a se mover ele retoma o percurso de cima para baixo; não pode ficar fixo na interface.

**Galões de gasolina — coleta**

- **FR-024**: A coleta deve seguir a sequência: detectar o contato entre a área do jogador e a do galão; confirmar o estado `PLAYING`; marcar o galão como coletado; desativá-lo ou removê-lo imediatamente do mundo da pista; restaurar a quantidade configurada por meio de uma interface pública do sistema de combustível; atualizar o medidor; e emitir o evento de coleta — uma única vez por galão, mesmo com sobreposição durando vários quadros. O contato com o galão **não aciona o comportamento de colisão** do jogo: nenhuma perda de velocidade, deriva, penalidade de combustível, cooldown ou evento de colisão — o contato vale apenas como coleta.
- **FR-025**: A quantidade restaurada é configurável — **um único valor global**, idêntico em qualquer corrida e ambiente (`fuel_can_restore_amount`) —, e o resultado é sempre `min(combustivel_atual + combustivel_recuperado, capacidade_tanque)`: nunca acima da capacidade, nunca negativo ou inválido; com o tanque cheio o galão desaparece sem alterar o valor; a coleta não altera a capacidade máxima do tanque.
- **FR-026**: O galão desaparece visualmente após a coleta, não reaparece na mesma posição durante a mesma corrida, e a interface ou o jogador não alteram diretamente o valor interno do combustível — apenas o sistema de combustível o faz.

**Galões de gasolina — geração e distribuição**

- **FR-027**: A geração deve ser controlada por um gerenciador de itens coletáveis próprio ou integrada ao gerenciador de trânsito apenas se isso for compatível com a arquitetura existente — antes de criar um novo componente, analisa-se se há um gerenciador reutilizável adequado, evitando concentrar responsabilidades incompatíveis no gerenciador de trânsito.
- **FR-028**: A geração deve ser orientada por distância (percorrida, total e desde a última geração), e não depender exclusivamente de temporizadores, considerando: dificuldade do ambiente, quantidade máxima de galões ativos, espaçamento mínimo entre itens, espaçamento em relação aos NPCs, espaçamento em relação ao início e à chegada e a quantidade de combustível que o item fornece; deve respeitar também um piso e um teto configuráveis, contados como **total de galões gerados em toda a corrida** (piso: ao menos N oportunidades apresentadas do início ao fim; teto: no máximo N galões gerados por corrida) — distintos da quantidade simultânea ativa, limitada por `fuel_can_max_active`.
- **FR-029**: A frequência deve variar conforme a dificuldade, segundo a diretriz inicial — planície (1): maior disponibilidade relativa; deserto (2): moderada; floresta (3): reduzida; gelo (4): mais restrita —, com os valores exatos configuráveis e sem valores mágicos espalhados pelo código; a diferença deve ser perceptível sem tornar nenhum ambiente impossível, e a distribuição deve levar em conta a distância total e o consumo esperado.
- **FR-030**: Antes de confirmar uma geração devem ser verificados: espaço suficiente em relação aos itens ativos; nunca posicionar sobre um NPC, garantindo que o jogador consiga interagir sem provocar colisão com NPCs; pertencer a uma posição válida da pista; respeito ao limite máximo de itens simultâneos e distância mínima do ponto de partida e da chegada; posição inválida leva a buscar outra ou a adiar; nenhuma geração ocorre fora de `PLAYING`; e a reciclagem de segmentos da estrada não pode ressuscitar um galão já coletado.

**Galões de gasolina — ciclo de vida e eventos**

- **FR-031**: O galão deve ser removido ou devolvido a um pool quando: coletado; sair completamente da área de jogo (atingir a base da tela) sem coletado — e nesse caso a devolução ao pool é obrigatória, para que ele possa ser apresentado novamente mais adiante na mesma corrida, em nova posição válida, dando nova oportunidade de interação —; a corrida for reiniciada; o jogador voltar ao menu; a corrida terminar em `VICTORY` ou `GAME_OVER`. Havendo pool, a reutilização deve redefinir posição, estado de coleta e referências de colisão; nenhum galão pode continuar ativo ou coletável após o encerramento da corrida.
- **FR-032**: Devem ser adotadas as convenções de eventos do projeto, com os eventos sugeridos `fuel_can_spawned`, `fuel_can_collected` e `fuel_changed`; o evento de coleta pode carregar a quantidade restaurada e a identificação do item; eventos duplicados para uma mesma coleta são proibidos.
- **FR-033**: O sistema de combustível mantém a autoridade exclusiva sobre seus valores: quantidade, capacidade, consumo, penalidades, restauração e eventos; nenhum outro componente (gerenciador de itens, interface ou jogador) escreve diretamente no estado interno do combustível.

**Reinício, menu e telas de fim**

- **FR-034**: As telas de vitória e de Game Over devem oferecer "Tentar novamente" e "Voltar ao menu"; a tela de pausa deve oferecer "Continuar", "Reiniciar" e "Voltar ao menu", reutilizando os mesmos fluxos de reinício e de retorno ao menu.
- **FR-035**: Ao reiniciar devem ser limpos ou reinicializados: distância e progresso, estado da chegada, marcador de início, combustível e estado de esgotamento, velocidade do jogador, NPCs, galões ativos, estado do gerenciador de itens coletáveis, efeitos temporários, temporizadores e eventos pendentes — sem duplicações de instâncias ou conexões.
- **FR-036**: Ao retornar ao menu, nenhum sistema de gameplay pode continuar avançando em segundo plano.

**Arquitetura, integração e configuração**

- **FR-037**: Devem ser preservadas as responsabilidades existentes, sem criar classes duplicadas: sistema de estados do jogo (`GameManager`) para estados e transições; sistema de progressão da pista (`TrackManager`) para distância, progresso e conclusão; sistema de combustível (`FuelSystem`) para quantidade, consumo, esgotamento e restauração; sistema de interface (`UIManager`) para menu, seleção de veículo, medidor de combustível, indicador de distância e telas finais; veículo do jogador e seu controlador para movimento, velocidade, frenagem e comportamento sem combustível; estrada para segmentos, rolagem e limites; gerenciador de trânsito e veículos de trânsito para NPCs; sistemas de colisão jogador×NPC e NPC×NPC; e o gerenciador de itens coletáveis para geração, posicionamento, coleta e remoção dos galões. Os nomes são sugestões e devem seguir as convenções do código existente.
- **FR-038**: A restauração de combustível por coleta deve entrar no sistema de combustível por uma interface pública apropriada, sem permitir que o gerenciador de itens ou a interface alterem diretamente seus valores internos.
- **FR-039**: Todos os parâmetros novos devem ficar centralizados na configuração, ajustáveis sem alteração da lógica, sem valores mágicos no código.
- **FR-040**: A implementação deve integrar-se às SPEC-001 a SPEC-007 sem regressões: controles, colisões, deriva, NPCs, trânsito, decoração, ambientes, estrada e combustível continuam funcionando, e as dimensões dos sprites dos veículos e suas hitboxes permanecem inalteradas.
- **FR-041**: Os textos de interface voltados ao usuário (`INÍCIO`, `CHEGADA`, `Distância: ...`, `Tentar novamente`, `Voltar ao menu`, `Continuar`, `Reiniciar` e demais rótulos) devem ficar externalizados, sem literais embutidos na lógica, para permitir a localização futura prevista na constituição.

**Parâmetros configuráveis** (nomes de referência, adaptáveis à convenção do projeto):

- `track_total_distance` — distância total da corrida;
- `fuel_consumption_per_distance` — consumo base por unidade de distância;
- `fuel_safety_margin` — margem de segurança do dimensionamento;
- `fuel_can_restore_amount` — combustível restaurado por galão (valor único global, idêntico em qualquer ambiente);
- `fuel_can_spawn_interval_distance` — distância entre gerações de galões;
- `fuel_can_min_spacing` — espaçamento mínimo entre galões;
- `fuel_can_npc_spacing` — espaçamento em relação aos NPCs;
- `fuel_can_start_offset` / `fuel_can_finish_offset` — distâncias mínimas do início e da chegada;
- `fuel_can_max_active` — quantidade máxima de galões simultâneos;
- `fuel_can_min_per_race` / `fuel_can_max_per_race` — piso e teto do **total de galões gerados em toda a corrida** (evitam ausência prolongada ou abundância excessiva); a quantidade simultânea é limitada por `fuel_can_max_active`;
- `fuel_can_spawn_rate` — frequência/densidade de geração por ambiente (`PLAINS`, `DESERT`, `FOREST`, `ICE`).

### Key Entities *(include if feature involves data)*

- **Estado de Jogo**: um dos seis estados (`MENU`, `READY`, `PLAYING`, `PAUSED`, `VICTORY`, `GAME_OVER`) da sessão corrente, com o estado anterior registrado para retomada. Invariante: exatamente um estado ativo por vez e somente o sistema central de estados o altera.
- **Corrida (Progressão da Pista)**: distância total configurável, distância percorrida, distância restante, percentual de progresso, estado de conclusão e posição lógica da linha de chegada. Invariantes: `0 ≤ percorrida ≤ total`; não decresce; só cresce com deslocamento efetivo em `PLAYING`.
- **Marcador de Pista**: elemento do mundo da pista (início ou chegada) com texto e faixa quadriculada, posição inicial, vínculo com a rolagem e estado ativo/inativo. O de início é descartado definitivamente ao sair da tela; o de chegada permanece até a conclusão.
- **Galão de Gasolina**: item coletável com asset de 32 × 51 px, posição válida na pista, área de contato, estado (ativo/coletado) e quantidade de combustível que fornece; **sem velocidade própria** (desloca-se apenas com a rolagem impulsionada pela velocidade do jogador) e **a coleta não é colisão** (nenhuma consequência de colisão). Invariantes: coletado no máximo uma vez por corrida; fora da área ou do `PLAYING` não é coletável; não coletado que sai da tela é devolvido ao pool e pode ser apresentado novamente em nova posição válida; nenhum ativo após o fim da corrida.
- **Configuração de Progressão e Itens**: conjunto centralizado dos parâmetros listados acima (distância, dimensionamento de combustível — do qual a capacidade e a carga inicial da corrida são derivadas em execução — e geração de galões por ambiente). Legível pelos sistemas sem alteração de código; origem única do balanceamento.
- **Eventos da Corrida**: notificações de vitória, Game Over, esgotamento (já existente — no máximo um por corrida, sem rearme), `fuel_can_spawned`, `fuel_can_collected` e `fuel_changed`, cada uma emitida no máximo uma vez por ocorrência que a originou.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das execuções, o jogo inicia em `MENU`; o menu permite iniciar a corrida e selecionar cada um dos dois veículos; a seleção padrão é o azul em 100% das corridas sem escolha explícita; a escolha do veículo produz 0 diferenças de atributos de gameplay e 0 alterações de dimensões ou hitboxes.
- **SC-002**: Em 100% das corridas, a marcação de início é exibida na posição inicial, desloca-se com a rolagem ao avançar e some da tela uma única vez — 0 reaparecimentos na mesma corrida.
- **SC-003**: Com o veículo em velocidade zero, 0 acréscimos de distância em 100% dos quadros; com o veículo mudando apenas de faixa (sem avançar), 0 acréscimos em 100% dos ensaios; durante a pausa, 0 acréscimos; ao retomar, desvio de progresso menor que 1% em relação ao valor da pausa; reciclagem de segmentos produz 0 alterações de distância.
- **SC-004**: A distância percorrida nunca excede a distância total — 0 ocorrências em partidas completas —, e o indicador apresentado diverge do progresso real em menos de 1% (100% das amostras).
- **SC-005**: 100% das vitórias exigem, no instante do cruzamento, estado `PLAYING`, combustível disponível e cruzamento completo; exatamente 1 evento de vitória por corrida vencida (0 repetidos) e 1 evento de Game Over por corrida perdida (0 repetidos).
- **SC-006**: Em 100% das corridas de referência (sem colisões nem coletas), o combustível dimensionado pela distância total permite cruzar a chegada, com a sobra final dentro da faixa de calibração definida para o balanceamento; a pausa congela o indicador de distância e o reinício o retorna a 0.
- **SC-007**: Em 100% dos esgotamentos: 0 novas acelerações iniciadas enquanto o combustível atual for zero (e 100% das acelerações voltam a ser permitidas após restauração em `PLAYING`), desaceleração gradual até velocidade zero (o veículo não é interrompido instantaneamente em nenhum ensaio), distância ainda crescente enquanto houver deslocamento e transição única para `GAME_OVER` ao parar com zero e sem concluir; o evento de esgotamento permanece único por corrida, inclusive com coleta e novo esgotamento no meio.
- **SC-008**: Em 100% dos ensaios, nada além da coleta de galões aumenta o combustível durante a corrida — 0 reforços automáticos.
- **SC-009**: Em 100% das coletas: o galão desaparece no mesmo instante, o combustível sobe imediatamente pela quantidade configurada, o valor resultante nunca ultrapassa a capacidade nem fica negativo, o medidor acompanha, 0 coletas duplicadas do mesmo galão, 0 eventos de coleta repetidos e 0 consequências de colisão (0 perdas de velocidade, 0 derivas, 0 penalidades de combustível, 0 cooldowns e 0 eventos de colisão originados pela coleta).
- **SC-010**: A frequência esperada de galões obedece à ordem planície > deserto > floresta > gelo em 100% das comparações de configuração; o limite máximo de itens ativos é respeitado em 100% dos quadros; o piso e o teto do total gerado por corrida são respeitados em 100% das corridas completas (corrida com menos que o piso ou mais que o teto = 0 ocorrências); 0 galões fora da pista válida, 0 em posição inalcançável, 0 posicionados sobre NPCs ou em pontos que exijam colidir com NPCs para coletar, e 0 com sobreposição inadequada de espaçamento em relação a NPCs, início e chegada.
- **SC-011**: Após qualquer encerramento (vitória, Game Over, reinício, retorno ao menu), 0 galões ativos ou coletáveis permanecem — verificado em 100% dos casos; galões não coletados que saem da tela são devolvidos ao pool e reutilizados com posição, estado e referências redefinidos — 0 itens acumulados fora da tela e 0 reaparecimentos com estado de coleta herdado.
- **SC-012**: Pausar e retomar com galões visíveis preserva posição e estado dos itens sem deslocamento acumulado (100% dos ensaios); reiniciar após coleta ou após Game Over produz 0 duplicações de itens e 0 conexões de eventos repetidas.
- **SC-013**: Zero regressões: 100% das suítes de teste das SPEC-001 a SPEC-007 permanecem verdes com a SPEC-008 ativa, incluindo as transições entre configurações de estrada de duas e quatro vias.
- **SC-014**: As dimensões visuais e as hitboxes dos veículos permanecem idênticas às validadas nas SPEC-004 e SPEC-005 — 0 alterações; o asset `gasolina.png` é usado com suas dimensões originais de 32 × 51 pixels em 100% dos galões.
- **SC-015**: 0 atualizações de combustível fora do sistema de combustível e 0 eventos duplicados (de vitória, Game Over, coleta, esgotamento ou mudança de combustível) em 100% das corridas executadas.
- **SC-016**: Todos os parâmetros novos são alteráveis somente por configuração, com 0 valores de balanceamento fixos na lógica, e cada alteração produz efeito observável em 100% dos casos.
- **SC-017**: O jogador consegue iniciar uma corrida a partir do menu, pausar (com "Continuar", "Reiniciar" e "Voltar ao menu" disponíveis em 100% das pausas) e chegar às telas de vitória ou Game Over com as opções "Tentar novamente" e "Voltar ao menu" em 100% dos fluxos percorridos.

## Assumptions

- As SPEC-001 a SPEC-007 estão concluídas e funcionais; esta spec as integra sem alterar seus comportamentos validados. A entrega escalonada prevista na emenda constitucional v3.0.0 (2026-10-10) é cumprida aqui: a SPEC-007 emite o sinal de esgotamento e esta spec realiza a transição para `GAME_OVER`.
- Os seis estados já existem no projeto e são mantidos; o estado `READY` é reservado à preparação breve entre o menu e a largada (o texto o qualifica como "se necessário") e permanece com o comportamento atual de preparação única por corrida.
- O controle de pausa já existente é mantido; a composição da tela de pausa foi decidida nas Clarifications de 2026-10-10: oferece **Continuar, Reiniciar e Voltar ao menu**, com os mesmos rótulos e fluxos das telas de vitória e Game Over.
- A distância total é um único valor configurável, com o valor inicial de referência do texto (`5,0 km`) tratado como provisório e calibrado no planejamento junto com o dimensionamento de combustível.
- **Capacidade derivada em tempo de execução (decidido nas Clarifications de 2026-10-10)**: a capacidade do tanque e a quantidade inicial de cada corrida resultam da fórmula `distância total × consumo base por unidade de distância + margem`, calculada no início da corrida — alterar a distância total muda o tanque automaticamente; a partida continua nascendo cheia (SPEC-007) e os limites válidos do sistema de combustível continuam valendo.
- **Sem rearme do esgotamento (decidido nas Clarifications de 2026-10-10)**: o evento de esgotamento permanece único por corrida, como na SPEC-007 (rearm somente em nova corrida, sem emenda); o bloqueio de aceleração e a transição para `GAME_OVER` derivam do valor atual de combustível, de modo que uma coleta em `PLAYING` reabilita a aceleração e um novo esgotamento na mesma corrida bloqueia de novo sem depender de um novo evento.
- **Comportamento do galão (decidido nas Clarifications de 2026-10-10)**: o galão não tem velocidade própria (só a rolagem o move, parando com o jogador); o galão não coletado que chega à base da tela é limpo e devolvido ao pool para nova apresentação na mesma corrida; a coleta não dispara comportamento de colisão (sem perda de velocidade, deriva, penalidade, cooldown ou evento de colisão); e o posicionamento nunca é sobre NPCs, garantindo interação sem provocar colisão.
- **Limites por corrida (decidido nas Clarifications de 2026-10-10)**: `fuel_can_min_per_race` e `fuel_can_max_per_race` limitam o **total de galões gerados em toda a corrida** (piso = ao menos N oportunidades apresentadas; teto = no máximo N gerados por corrida); a quantidade simultânea ativa continua limitada por `fuel_can_max_active` e o piso de disponibilidade continua evitando ausências prolongadas.
- **Distância = avanço pela pista (decidido nas Clarifications de 2026-10-10)**: só o componente de avanço do veículo — o mesmo que impulsiona a rolagem — acumula distância; mudança de faixa sem avançar soma zero.
- **Restauração global (decidido nas Clarifications de 2026-10-10)**: `fuel_can_restore_amount` é um valor único global — todos os galões, em qualquer ambiente, restauram a mesma quantidade; a dificuldade dos ambientes varia pela frequência de geração, não pela quantidade por item.
- A interface exibe a distância em quilômetros com uma casa decimal (formato de referência `Distância: 2,4 km / 5,0 km`); a unidade de cálculo interna é consistente com a unidade já usada pela velocidade do jogo, convertida apenas para exibição.
- O asset `gasolina.png` (32 × 51 px) já está presente no projeto em `assets/decoracao/gasolina.png` — dimensões verificadas; esta spec não o redesenha nem o duplica, e o caminho definitivo de uso é confirmado no planejamento seguindo a organização existente.
- A dificuldade é a dos quatro ambientes já existentes (planície 1, deserto 2, floresta 3, gelo 4), obtida do sistema de ambientes no momento da geração; mudanças de ambiente em runtime valem para as gerações seguintes, sem retroatividade.
- A geração de galões deve ser orientada por distância; a escolha entre um gerenciador de itens coletáveis dedicado e uma integração ao gerenciador de trânsito é decidida no planejamento depois da análise prevista no FR-027 — a regra é não misturar responsabilidades incompatíveis.
- A ordem de atualização por quadro (colisão → coleta de itens → combustível → transição de estado) é definida no planejamento, com a única exigência de ser única, consistente e de garantir que `GAME_OVER` nunca seja revertido por uma coleta.
- A precedência entre chegada e esgotamento é a do texto-fonte: sem combustível disponível no instante do cruzamento completo não há vitória, mesmo que o movimento residual passe da linha.
- Unidade abstrata de combustível da SPEC-007 é mantida; o dimensionamento por distância adapta-se ao modelo de consumo existente (tempo × velocidade) em vez de substituí-lo.
- **Testes obrigatórios**: o texto-fonte exige os testes A a I da seção 16 — **cobertos pelas Acceptance Scenarios** (os 9 testes do texto-fonte não correspondem 1 a 1 aos cenários): Teste A (início) → US2 AS7–AS10; Teste B (distância) → US2 AS1–AS6; Teste C (chegada) → US2 AS9 + US3 AS1–AS4; Teste D (combustível) → US4 AS1–AS4 + US5 AS2; Teste E (coleta) → US6 AS1–AS10; Teste F (dificuldade e geração) → US7 AS1–AS7; Teste G (esgotado e coleta) → US4 AS5–AS7 + US6 AS3–AS6; Teste H (ciclo de vida) → US1 AS4–AS9 + US7 AS7 + US6 AS8/AS10; Teste I (regressão) → US1 AS3 + FR-040/SC-013/SC-014. A exigência fica registrada aqui para que o plano de tarefas os inclua.
- **Cobertura dos 24 critérios de aceitação do texto-fonte (seção 15)**: 1 → FR-002/SC-001; 2 → FR-010/SC-002; 3 → FR-011/SC-004; 4 → FR-013/FR-014/SC-005; 5 → FR-009/SC-004; 6 → FR-018/SC-006; 7 → FR-040/SC-013 (o aviso de combustível baixo da SPEC-007 permanece apenas aviso, sem mudança de comportamento); 8 → FR-015/SC-007; 9 → FR-015/SC-007; 10 → FR-016/SC-005; 11 → FR-021/SC-014; 12 → FR-022/SC-010; 13 → FR-023/SC-010; 14 → FR-024/SC-009; 15 → FR-025/SC-009; 16 → FR-024/SC-009; 17 → FR-029/SC-010; 18 → FR-028/FR-030/SC-010; 19 → FR-031/SC-011; 20 → FR-004/SC-012; 21 → FR-035/SC-012; 22 → FR-040/SC-013; 23 → FR-040/SC-014; 24 → FR-032/FR-033/SC-015.
- **Escopo de apresentação**: indicador de distância no mesmo padrão visual do medidor de combustível já existente, marcações de início/chegada no mundo da pista e telas de menu, vitória e Game Over com as opções exigidas; sons, animações e efeitos avançados não são obrigatórios nesta especificação.
- Textos de usuário externalizados conforme o §VI da constituição (pt-BR agora, en-US futuro sem refatoração).

## Out of Scope

Os itens a seguir estão explicitamente fora do escopo desta especificação e não devem ser implementados:

- Alteração das dimensões visuais ou das hitboxes dos veículos (jogador ou NPCs).
- Atributos de gameplay distintos por veículo escolhido.
- Novos controles de jogador além dos quatro já existentes (acelerar, frear, esquerda, direita) e do controle de pausa já existente.
- Postos de combustível, reabastecimento fora dos galões ou reforço automático de combustível em prova.
- Combustíveis especiais, itens coletáveis distintos dos galões (moedas, potencializadores etc.).
- Pontuação, ranking, recordes, progressão entre corridas ou desbloqueios.
- Multijogador, serviços online, armas, combate ou mecânicas fora do escopo da constituição.
- Sons, animações e efeitos visuais avançados para as novas telas e marcações.
- Redesenho ou reescalamento do asset `gasolina.png` além da escala de exibição pixel-art necessária.
- Modificação do modelo de consumo de combustível da SPEC-007 (o dimensionamento adapta-se a ele, não o substitui).
- Alteração da lógica de rolagem, de transição de faixas ou de geração de trânsito e decoração das specs anteriores, salvo o estritamente necessário para posicionar marcações e galões.
