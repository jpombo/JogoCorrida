# Feature Specification: Recordes, Persistência, Troféus, Pontuação e Obstáculos

**Feature Branch**: `011-records-trophies-obstacles`

**Created**: 2026-10-17

**Status**: Draft

**Input**: Especificação fornecida pelo usuário: "SPEC-012 — Recordes, Persistência, Troféus, Pontuação e Obstáculos" *(rótulo original do documento; adotada a numeração sequencial 011 conforme decisão do usuário em 2026-10-17 — todas as referências internas passam a usar SPEC-011)* — sistema persistente de recordes por modo, pontuação (distância + troféus − combustível perdido em colisões), troféus por conclusão dos quatro ambientes com ícones por modo, dois novos obstáculos (poça de água e cascalho) com efeitos temporários no veículo, desbloqueio progressivo dos obstáculos no modo Relaxante e persistência entre sessões — integrando-se aos sistemas já implementados de movimentação, colisão, combustível, progressão da pista, dificuldade, ambientes, áudio e interface.

## Clarifications

### Session 2026-10-17

- Q: A derrota (Fim de Jogo) zera o progresso do ciclo de troféus (ambientes já marcados no ciclo atual)? → A: **Sim — a derrota zera o ciclo de troféus do modo vigente**, espelhando o reset de ciclo já existente da SPEC-009; a quantidade total de troféus conquistados é sempre preservada.
- Q: Corridas que terminam em Fim de Jogo também registram resultado e atualizam recordes? → A: **Não — somente vitórias (ambiente concluído) registram resultado e podem atualizar recorde**; a derrota não gera registro.
- Q: Qual efeito exato a poça de água deve causar no veículo do jogador ao ser atingida? → A: **Redução temporária de aderência lateral** — o veículo escorrega mais ao mudar de faixa ou curvar, com recuperação gradual até o normal, sem deixar o veículo incontrolável (opção A, 2026-10-17). **Ajustado no aceite (T032, 2026-10-17)**: a poça passa a causar um **desvio lateral de meio carro** para o lado da posição do impacto, permanecendo visível e inerte na pista até sair da tela — a redução de aderência foi removida (parâmetro único `poca_desvio_lateral`).
- Q: Onde a pontuação da corrida, o recorde do modo e os troféus devem ser exibidos? → A: **No menu inicial e nas telas de vitória e Fim de Jogo** — durante a corrida nenhum elemento novo é acrescentado (mantêm-se apenas o indicador de distância e o HUD de combustível existentes) (opção A, 2026-10-17).
- Q: A pontuação acumulada por modo deve ser exibida na interface ou apenas persistida? → A: **Exibida no menu e nas telas de vitória/Fim de Jogo, junto do recorde do modo**; é a soma das pontuações dos resultados registrados daquele modo (opção A, 2026-10-17).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pontuar a corrida e manter recordes por modo, persistidos (Priority: P1)

Ao vencer uma corrida, o jogo calcula a pontuação daquela corrida somando os pontos da distância percorrida e dos troféus do modo, e descontando a penalidade do combustível perdido exclusivamente em colisões. O resultado é registrado (modo, ambiente, distância, pontuação, troféus, perda por colisão) e só atualiza o recorde do modo quando a pontuação supera a anterior — cada modo tem seu próprio recorde. Tudo isso é salvo e recuperado quando o jogo é feito e aberto de novo, com valores padrão na primeira execução e sem duplicar resultados ou pontos.

**Why this priority**: É o núcleo da spec — sem pontuação, recordes e persistência não há o que exibir, conquistar ou proteger entre sessões; entrega valor autossuficiente (correr, pontuar, bater recorde, recorde sobreviver ao reinício) antes de troféus e obstáculos.

**Independent Test**: Vencer corridas nos três modos, conferir a fórmula (distância − colisões), conferir que cada modo guarda seu próprio recorde, fechar e reabrir o jogo e conferir recordes/histórico idênticos; perder uma corrida e conferir que nenhum resultado foi registrado.

**Acceptance Scenarios**:

1. **Given** uma corrida vencida sem colisões, **When** o resultado é registrado, **Then** a pontuação usa distância e troféus com zero de penalidade por combustível.
2. **Given** uma corrida vencida com colisões que perderam combustível, **When** o resultado é registrado, **Then** a perda de combustível daqueles eventos é descontada exatamente uma vez, e o consumo normal de combustível não gera nenhum desconto.
3. **Given** recordes distintos nos três modos, **When** um resultado do modo Relaxante supera o recorde, **Then** apenas o recorde do Relaxante muda — os do Normal e do Desafio permanecem intactos.
4. **Given** um modo ainda sem recorde, **When** o primeiro resultado válido é registrado, **Then** o recorde desse modo é inicializado com essa pontuação.
5. **Given** um recorde existente, **When** o resultado obtido é menor ou igual a ele, **Then** o recorde permanece inalterado.
6. **Given** resultados e recordes registrados, **When** o jogo é fechado e aberto novamente, **Then** recordes, histórico e totais são restaurados sem perda e sem duplicação de registros.
7. **Given** uma corrida perdida (Fim de Jogo), **When** a corrida encerra, **Then** nenhum resultado é registrado e nenhum recorde é alterado.
8. **Given** uma vitória, **When** o encerramento processa o resultado, **Then** a pontuação final é calculada antes da atualização do recorde, e a corrida gera exatamente um registro.

---

### User Story 2 - Conquistar troféus por completar os quatro ambientes, por modo (Priority: P2)

Cada modo de jogo tem seu próprio progresso de troféus: ao vencer os quatro ambientes (planície, deserto, floresta e gelo) — cada um contando uma única vez por ciclo — o jogador ganha um troféu, o ciclo reinicia e um novo ciclo pode começar, indefinidamente. A interface mostra o ícone do modo atual, a quantidade de troféus e o progresso para o próximo (ex.: "2 troféus — Próximo: 3/4 ambientes"), atualizando corretamente ao trocar de modo sem misturar o progresso dos modos.

**Why this priority**: Dá ao jogo um objetivo de longa duração além da pontuação e alimenta diretamente a pontuação (componente de troféus) e o desbloqueio dos obstáculos do modo Relaxante; depende apenas do fluxo de vitória/derrota e da persistência já entregues na P1.

**Independent Test**: Vencer os 4 ambientes no modo Relaxante e conferir exatamente +1 troféu com o ciclo zerado; repetir para outros ciclos e modos; perder uma corrida e conferir o reset do ciclo com o total preservado; alternar modos no menu e conferir ícone/contador/progresso; reiniciar o jogo e conferir o progresso restaurado.

**Acceptance Scenarios**:

1. **Given** um ciclo vazio no modo vigente, **When** o jogador vence planície, deserto, floresta e gelo (ambientes distintos), **Then** o modo recebe exatamente +1 troféu e o progresso do ciclo é reiniciado.
2. **Given** um ambiente já marcado no ciclo atual, **When** ele é vencido novamente, **Then** o progresso do ciclo não muda — o ambiente conta apenas uma vez por ciclo e os demais ambientes pendentes permanecem marcados.
3. **Given** ciclos completos repetidos, **When** três ciclos são concluídos, **Then** o modo acumula exatamente três troféus.
4. **Given** progresso parcial no ciclo (ex.: 2 de 4 ambientes), **When** a corrida termina em Fim de Jogo, **Then** o ciclo do modo vigente é zerado e a quantidade total de troféus é preservada.
5. **Given** dois troféus no Relaxante e um no Normal, **When** o jogador consulta o Desafio, **Then** o Desafio mantém o seu próprio total e o seu próprio progresso — nenhuma operação altera o progresso de outro modo.
6. **Given** a interface em qualquer tela que exiba troféus, **When** o modo atual é Relaxante, **Then** é exibido `trofeu-relaxante.png`; com Normal, `trofeu-normal.png`; com Desafio, `trofeu-desafio.png` — sempre com a quantidade de troféus e o progresso "k/4 ambientes".
7. **Given** o menu com modo Relaxante selecionado, **When** o jogador alterna para Normal, **Then** o ícone e os números passam a ser os do Normal, sem misturar contadores ou progresso.
8. **Given** troféus e progresso conquistados, **When** o jogo é reiniciado, **Then** totais e ciclos de cada modo são restaurados exatamente como estavam.

---

### User Story 3 - Enfrentar os obstáculos poça de água e cascalho (Priority: P3)

Dois novos obstáculos passam a aparecer nos quatro ambientes: a **poça de água** (`poca.png`) desvia lateralmente o veículo do jogador em **meio carro** ao ser atingida — o lado depende da posição do impacto —, permanecendo visível e inerte na pista até sair da tela; o **cascalho** (`cascalho.png`) reduz temporariamente a velocidade. O cascalho tem parâmetros configuráveis de intensidade e duração e seu efeito termina sozinho; nada é permanente, nenhum mexe no combustível, e as colisões são detectadas de forma confiável mesmo na maior velocidade do modo Desafio, respeitando os limites da pista e sem bloquear a passagem inteira.

**Why this priority**: É o conteúdo novo de gameplay da spec; só faz sentido depois que o fluxo de corrida/pontuação está estável e é verificável de forma independente (colidir → efeito → término).

**Independent Test**: Atravessar uma poça (confirmando o desvio de meio carro para o lado do impacto e a permanência inerte até a saída da tela) e um cascalho em cada um dos três modos, medindo o efeito e o retorno automático ao normal; sondar encontros na maior velocidade do Desafio confirmando zero atravessamentos; conferir combustível inalterado e posicionamento dentro da pista.

**Acceptance Scenarios**:

1. **Given** os quatro ambientes, **When** a corrida roda em cada um, **Then** poça de água e cascalho podem aparecer nos quatro (planície, deserto, floresta e gelo).
2. **Given** o veículo do jogador atingindo uma poça, **When** o impacto ocorre, **Then** o veículo é desviado lateralmente de meio carro para o lado da posição do impacto (centro do carro à esquerda do centro da poça ⇒ esquerda; à direita ⇒ direita), sem sair dos limites da pista.
3. **Given** a poça atingida, **When** a rolagem da estrada continua, **Then** a poça permanece visível e inerte na pista (sem novo desvio, sem efeito residual) até sair da área da tela, quando então é removida.
4. **Given** o veículo do jogador atingindo o cascalho, **When** o efeito é aplicado, **Then** ocorre uma redução temporária perceptível da velocidade (eventualmente acompanhada de uma pequena redução de estabilidade, dentro do configurado).
5. **Given** o efeito do cascalho ativo, **When** a duração configurada termina, **Then** a velocidade e a estabilidade retornam ao normal automaticamente.
6. **Given** qualquer obstáculo atingido, **When** o efeito está em andamento, **Then** o combustível do jogador não sofre nenhuma alteração por causa dele.
7. **Given** o modo Desafio (maior velocidade do jogo), **When** o veículo cruza a posição de um obstáculo em encontros de referência, **Then** o efeito é ativado em 100% dos encontros — nenhum atravessamento sem ativação.
8. **Given** o posicionamento dos obstáculos, **When** observada a pista, **Then** todos ficam dentro dos limites da estrada, sem sobreposição com outros obstáculos ou NPCs, sem bloquear toda a passagem disponível e com aparência visual coincidente com a área de ativação.

---

### User Story 4 - Desbloquear obstáculos no Relaxante e integrar tudo à interface e ao fluxo (Priority: P4)

No modo Relaxante, poça e cascalho nascem bloqueados e só são desbloqueados — para sempre — quando o jogador conquista o primeiro troféu **nesse modo**; em Normal e Desafio já estão disponíveis desde a primeira corrida. A interface passa a mostrar, nos momentos certos do fluxo, a pontuação da corrida, o recorde do modo, o ícone/quantidade/progresso de troféus e o estado dos obstáculos, atualizando tudo de forma consistente a cada vitória, derrota e troca de modo — sem criar estados de jogo paralelos nem duplicar responsabilidades dos sistemas existentes.

**Why this priority**: É o acabamento que amarra os três eixos anteriores (troféus × obstáculos × interface); depende dos troféus (P2), dos obstáculos (P3) e da persistência (P1), por isso vem por último.

**Independent Test**: Jogar no Relaxante sem troféus e conferir os obstáculos bloqueados; conquistar o primeiro troféu no Relaxante e conferir o desbloqueio; reiniciar e conferir que persiste; conferir Normal/Desafio com obstáculos livres desde o início; conferir as telas de vitória/fim de jogo com pontuação, recorde e troféus após cada corrida.

**Acceptance Scenarios**:

1. **Given** modo Relaxante sem nenhum troféu, **When** uma corrida inicia, **Then** poça de água e cascalho permanecem bloqueados (não aparecem).
2. **Given** o primeiro troféu conquistado no modo Relaxante, **When** a conquista é registrada, **Then** os dois obstáculos são desbloqueados e permanecem desbloqueados permanentemente nesse modo.
3. **Given** obstáculos desbloqueados no Relaxante, **When** o jogo é reiniciado, **Then** o desbloqueio permanece valendo.
4. **Given** troféus conquistados apenas nos modos Normal e Desafio, **When** o jogador joga no Relaxante, **Then** os obstáculos continuam bloqueados — troféus de outros modos não desbloqueiam.
5. **Given** os modos Normal e Desafio, **When** a primeira corrida deles inicia (sem nenhum troféu), **Then** os dois obstáculos já estão disponíveis.
6. **Given** uma vitória ou um Fim de Jogo, **When** a tela de encerramento aparece, **Then** a pontuação da corrida (na vitória), o recorde do modo, a quantidade de troféus e o progresso do ciclo são exibidos e consistentes com os dados persistidos.
7. **Given** a troca de modo no menu, **When** o modo muda, **Then** ícone, recorde, troféus e estado de desbloqueio exibidos passam a ser os do novo modo.
8. **Given** o encerramento de uma corrida, **When** os dados são salvos, **Then** a gravação acontece uma única vez por corrida — sem duplicar resultados, pontos ou troféus.
9. **Given** as resoluções suportadas pelo jogo, **When** os novos elementos são exibidos, **Then** permanecem legíveis e sem sobreposição com os elementos já existentes.

---

### Edge Cases

- Primeira execução sem nenhum dado salvo → todos os valores padrão são carregados (recorde 0/ausente, 0 troféus, ciclo vazio, obstáculos do Relaxante bloqueados), sem falhas.
- Arquivo de dados ausente, corrompido ou inválido → tratamento seguro com valores padrão, sem travamento e sem sobrescrever silenciosamente dados válidos já existentes.
- Resultado igual ao recorde registrado → o recorde **não** é substituído (só pontuação estritamente superior).
- Corrida perdida → nenhum resultado/recorde; ciclo de troféus do modo vigente zerado e total de troféus preservado.
- Vencer o mesmo ambiente duas vezes no mesmo ciclo de troféus → progresso inalterado; os ambientes pendentes não são removidos.
- Completar o ciclo de troféus na mesma corrida que supera o recorde → troféu e recorde atualizados uma única vez, na ordem correta (pontuação calculada antes do recorde), sem duplicação.
- Troféus em Normal/Desafio → zero efeito sobre o desbloqueio do Relaxante.
- Troca de modo durante o menu com corridas em curso interrompidas → exibição sempre do modo selecionado; nenhum número de um modo aparece no outro.
- Colisão com obstáculo enquanto o efeito já está ativo → o efeito é reafirmado/renovado sem empilhar intensidade nem dobrar a duração.
- Obstáculo atingido durante a pausa → nada avança e nenhuma nova detecção acontece enquanto pausado; o efeito do cascalho permanece congelado e a poça permanece inerte — ambos retomam ao continuar.
- Ambientes com penalidade de colisão zero (planície/deserto) → perda de combustível por colisão registrada como 0, penalidade de pontuação 0, sem erro de cálculo.
- Vitória em que a distância é máxima (chegada cruzada) → distância usada na pontuação é exatamente a medida única do progresso da pista (nunca maior que o total).
- Vitória sem nenhum troféu no modo → componente de troféus da pontuação contribui 0.
- Reinício/volta ao menu logo após um encerramento → o registro da corrida anterior não é reaplicado nem duplicado.
- Máxima velocidade do Desafio combinada com obstáculo → sem atravessamento sem ativação do efeito (detecção confiável).
- Obstáculo nascendo sobre a posição do jogador ou de um NPC → posicionamento inválido é descartado/reagendado, nunca gerado.
- Falha de gravação no encerramento → os dados válidos previamente salvos permanecem intactos.

## Requirements *(mandatory)*

### Functional Requirements

**Registro de resultados e recordes**

- **FR-001**: O jogo deve registrar, para cada **vitória**, um resultado contendo no mínimo: modo de jogo, ambiente concluído, distância percorrida, pontuação obtida, quantidade de troféus do modo até aquele momento, combustível perdido especificamente por colisões na corrida e data/hora quando disponível; o resultado da corrida deve ser distinguido dos totais acumulados do jogador, e todas as informações devem ser obtidas dos sistemas já existentes de progressão, dificuldade e combustível/colisão — sem criar fontes duplicadas de dados.
- **FR-002**: Devem existir recordes independentes de maior pontuação para os modos Relaxante, Normal e Desafio; um recorde só é atualizado quando a nova pontuação **superar** estritamente a anterior do **mesmo modo**; o primeiro resultado válido de um modo inicializa o seu recorde; nenhum resultado de um modo pode alterar o recorde de outro; os recordes devem ser persistidos e recuperados na inicialização do jogo.
- **FR-003**: Somente as corridas vencidas (ambiente concluído) geram registro de resultado e podem atualizar recordes; corridas encerradas em Fim de Jogo não registram resultado nem alteram recordes.

**Sistema de pontuação**

- **FR-004**: A pontuação de cada corrida deve ser calculada pela fórmula `Pontuação = (Pontos de distância × Peso da distância) + (Troféus × Peso dos troféus) − (Combustível perdido por colisões × Peso da penalidade)`, com todos os pesos configuráveis por uma fonte centralizada de balanceamento e valores iniciais razoáveis.
- **FR-005**: Os pontos de distância devem usar exclusivamente a medida única de distância já existente no sistema de progressão da pista, com a conversão distância→pontos definida de forma centralizada e configurável — nenhum cálculo paralelo de distância.
- **FR-006**: A contribuição de troféus deve usar a quantidade de troféus do modo vigente no momento do encerramento (incluindo o troféu conquistado na própria corrida, quando houver), calculada uma única vez — a mesma conquista não pode gerar pontos duplicados.
- **FR-007**: Somente o combustível perdido **em decorrência de colisões** deve gerar penalidade de pontuação, usando os eventos e valores já fornecidos pelos sistemas de colisão e de combustível; o consumo normal de combustível não pode ser penalizado, e a mesma perda não pode ser contabilizada mais de uma vez.
- **FR-008**: O sistema deve distinguir a pontuação final da corrida atual, a pontuação acumulada por modo (soma das pontuações dos resultados registrados daquele modo — exibida na interface e persistida) e a melhor pontuação registrada (recorde) de cada modo; a pontuação final deve ser definida em um momento consistente do encerramento, **sempre antes** de atualizar recordes e persistir o resultado — sem duplicação de pontos ao salvar ou encerrar.

**Sistema de troféus**

- **FR-009**: O jogador deve conquistar exatamente um troféu do modo vigente ao concluir os quatro ambientes (planície, deserto, floresta e gelo); cada ambiente conta apenas uma vez por ciclo de conquista; concluir um ambiente já registrado no ciclo não pode alterar nem remover o progresso dos ambientes ainda pendentes; ao completar os quatro: concede o troféu, incrementa o total do modo, reinicia o ciclo e permite novos ciclos indefinidamente.
- **FR-010**: O progresso de troféus deve ser armazenado separadamente para Relaxante, Normal e Desafio — cada modo com sua quantidade total, seus ambientes concluídos no ciclo atual, seu progresso para o próximo troféu e o histórico necessário para persistência; nenhuma operação em um modo pode alterar o progresso de outro.
- **FR-011**: Uma derrota (Fim de Jogo) deve zerar o progresso do ciclo de troféus do modo vigente, preservando sempre a quantidade total de troféus já conquistados.
- **FR-012**: A interface deve exibir o ícone do modo atual acompanhado da quantidade de troféus e do progresso para a próxima conquista no formato "quantidade + próximo k/4 ambientes" (ex.: `[Ícone] 2 troféus — Próximo: 3/4 ambientes`, adaptável visualmente); a troca de modo deve atualizar ícone, quantidade e progresso sem misturar dados entre modos.
- **FR-013**: Os ícones devem usar os assets previstos por modo — Relaxante `trofeu-relaxante.png`, Normal `trofeu-normal.png`, Desafio `trofeu-desafio.png` —, todos na dimensão visual de 32 px prevista, com alinhamento adequado ao contador e legibilidade nas resoluções suportadas, e uma configuração centralizada que associe cada modo ao seu asset (sem lógica de troféus duplicada).

**Obstáculos: poça de água e cascalho**

- **FR-014**: O obstáculo **poça de água** (`poca.png`, 48 × 35 px) deve aparecer nos quatro ambientes e, ao ser atingido pelo veículo do jogador, causar um **desvio lateral instantâneo de meio carro** para o lado da posição do impacto (distância configurável), sem empurrar o veículo para fora dos limites da pista; após o impacto a poça permanece **visível e inerte** na pista até sair da área da tela — não desaparece no impacto, não gera novo desvio na mesma passada e não aplica efeito residual no veículo — e **sem alteração direta do combustível**. *(Ajuste do aceite T032: substitui a redução temporária de aderência lateral original.)*
- **FR-015**: O obstáculo **cascalho** (`cascalho.png`, 48 × 27 px) deve aparecer nos quatro ambientes e, ao ser atingido pelo veículo do jogador, causar uma redução **temporária** de velocidade — podendo ainda, se configurado, aplicar uma pequena redução temporária de estabilidade que não torne a condução excessivamente difícil — com intensidade e duração configuráveis, término automático, sem dano permanente e **sem alteração direta do combustível**.
- **FR-016**: Os efeitos **temporizados** dos obstáculos (cascalho) devem terminar automaticamente ao fim do período configurado, restaurando o comportamento normal; colisões repetidas durante um efeito ativo não podem empilhar intensidade nem dobrar a duração; os efeitos devem permanecer congelados enquanto o jogo estiver pausado. O desvio da poça não é um efeito temporizado: acontece uma única vez por impacto, não tem duração nem a ser restaurada.
- **FR-017**: A distribuição deve respeitar a perspectiva top-down e a geometria da estrada existente, os limites dinâmicos da pista e os mecanismos de geração/progressão já implementados, evitando: sobreposição com outros obstáculos, bloqueio de toda a passagem disponível, sobreposição com veículos NPC, posicionamento fora da pista e divergência entre aparência visual e área de ativação — sem recriar os sistemas de estrada ou de spawn de NPCs.

**Disponibilidade e desbloqueio dos obstáculos**

- **FR-018**: A disponibilidade deve seguir a regra: no modo **Relaxante**, poça e cascalho nascem bloqueados e são desbloqueados permanentemente ao conquistar o **primeiro troféu nesse modo**; em **Normal** e **Desafio**, ambos estão disponíveis desde a primeira corrida.
- **FR-019**: O desbloqueio do Relaxante deve ser derivado do progresso persistido (ou armazenado explicitamente), permanecer válido após reiniciar o jogo, e **nunca** pode ocorrer por troféus conquistados nos modos Normal ou Desafio.
- **FR-020**: A detecção de ativação dos obstáculos deve ser confiável em todas as velocidades dos três modos, incluindo a maior velocidade do Desafio — nenhum atravessamento do veículo sem ativação do efeito —, usando estratégia de detecção compatível com a arquitetura atual.

**Persistência dos dados**

- **FR-021**: A persistência deve ser centralizada em um componente único e incluir, no mínimo: recordes dos três modos, histórico de resultados, pontuação acumulada por modo (soma dos resultados registrados, exibida e persistida), quantidade de troféus por modo, ambientes concluídos no ciclo atual por modo, progresso para o próximo troféu por modo, estado de desbloqueio dos obstáculos no modo Relaxante e demais dados necessários para reconstruir a progressão.
- **FR-022**: Ao iniciar, o jogo deve carregar os dados existentes; sem dados, inicializar valores padrão; atualizar após eventos relevantes; nunca sobrescrever informações válidas com valores padrão; nunca duplicar resultados, pontos ou troféus; tratar arquivos ausentes ou inválidos de forma segura; e preservar a independência entre os três modos — tudo gravado em localização apropriada de dados persistentes do usuário, com mecanismos compatíveis com a versão da engine do projeto.

**Integração com interface, fluxo e dificuldade**

- **FR-023**: A interface deve exibir, **no menu inicial e nas telas de vitória e Fim de Jogo**, a pontuação da corrida (na vitória), a pontuação acumulada do modo, o recorde do modo atual, o ícone/quantidade/progresso de troféus e o estado de desbloqueio dos obstáculos, atualizando após conquista de troféu, desbloqueio, vitória e derrota, com persistência em momentos consistentes do encerramento (cálculo da pontuação → atualização de recorde → gravação); **durante a corrida nenhum elemento novo é acrescentado à exibição** (permanecem apenas o indicador de distância e o HUD de combustível existentes), respeitando a organização visual existente e a legibilidade em todas as resoluções suportadas.
- **FR-024**: A implementação não pode criar um fluxo paralelo de estados de jogo nem duplicar responsabilidades dos sistemas centrais de estado, progressão e interface; os estados existentes (MENU, READY, PLAYING, PAUSED, VICTORY, GAME_OVER) e seus fluxos permanecem os únicos.
- **FR-025**: Os multiplicadores e parâmetros de dificuldade já definidos na SPEC-009 não podem ser alterados nem duplicados por lógica paralela; os efeitos dos obstáculos devem funcionar de forma consistente nas velocidades dos três modos.
- **FR-026**: Todos os parâmetros de balanceamento novos devem ser centralizados e configuráveis sem alteração da lógica: pesos da fórmula de pontuação, conversão da distância em pontos, pontos por troféu, penalidade por unidade de combustível perdida em colisão, distância do desvio da poça, intensidade/duração/estabilidade do cascalho, parâmetros de distribuição dos obstáculos e associação modo→asset de troféu — sem números mágicos espalhados pelo código.
- **FR-027**: A implementação deve integrar-se aos sistemas existentes (movimentação, colisão, combustível, trânsito, progressão da pista, ambientes, dificuldade, áudio e interface) sem regressões, reutilizando-os em vez de recriá-los — nenhum sistema paralelo de progressão, combustível ou colisão.

### Key Entities

- **Resultado de Corrida**: o registro de uma vitória — modo, ambiente concluído, distância percorrida, pontuação, troféus do modo naquele momento, combustível perdido por colisões e data/hora; pertence a uma corrida específica, distinto dos totais acumulados.
- **Recorde por Modo**: a maior pontuação já registrada em cada modo (Relaxante, Normal, Desafio); atualizada apenas por pontuação estritamente superior no mesmo modo.
- **Pontuação**: valor derivado de três componentes — distância percorrida (positivo), troféus do modo (positivo) e combustível perdido em colisões (negativo) — com pesos configuráveis; distinta da pontuação acumulada por modo e do recorde.
- **Pontuação Acumulada por Modo**: a soma das pontuações de todos os resultados registrados (vitórias) daquele modo; exibida no menu e nas telas de fim junto do recorde e persistida.
- **Progresso de Troféus por Modo**: total de troféus conquistados, conjunto de ambientes já concluídos no ciclo atual e progresso para o próximo troféu; independente entre os três modos; zerado na derrota (total preservado).
- **Obstáculo de Pista**: poça de água e cascalho — cada um com asset, área de ativação, regra de comportamento no impacto (poça: desvio lateral de meio carro + inércia até sair da tela; cascalho: efeito temporário de intensidade e duração) e regra de disponibilidade por modo; atuam apenas sobre o veículo do jogador.
- **Estado de Desbloqueio (Relaxante)**: se os obstáculos já foram liberados no modo Relaxante — derivado do primeiro troféu conquistado e persistido.
- **Dados Persistidos do Jogador**: o conjunto salvo entre sessões — recordes, histórico, acumulados, troféus, ciclos e desbloqueio — fonte única de restauração da progressão.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Recordes: em 100% dos ensaios, um resultado só altera o recorde do seu próprio modo e apenas quando supera estritamente o valor anterior — 0 sobrescritas entre modos e 0 substituições por pontuação menor ou igual; o primeiro resultado de um modo inicializa o seu recorde em 100% dos casos.
- **SC-002**: Pontuação: em 100% das corridas de referência, a pontuação final difere menos de 1% do valor esperado pela fórmula configurada; corridas sem colisões têm 0 de penalidade; o consumo normal de combustível gera 0 de penalidade; cada evento de colisão conta exatamente 1 vez — 0 perdas contabilizadas em duplicidade.
- **SC-003**: Ordenação do fluxo: em 100% dos encerramentos, a pontuação final usada para avaliar o recorde é exatamente a pontuação da corrida (0 divergências), calculada antes de qualquer atualização de recorde ou gravação, e cada vitória gera exatamente 1 registro — 0 duplicações.
- **SC-004**: Troféus: a cada 4 ambientes distintos vencidos no modo, exatamente +1 troféu (0 a mais, 0 a menos); 3 ciclos completos → exatamente 3 troféus; repetir um ambiente já marcado no ciclo altera o progresso em 0 passos; a derrota zera o ciclo do modo em 100% dos casos preservando o total (0 perdas de troféu).
- **SC-005**: Independência entre modos: em 100% das operações (resultado, troféu, desbloqueio, consulta), 0 alterações cruzadas entre Relaxante, Normal e Desafio; após reiniciar, cada modo restaura exatamente os seus próprios valores.
- **SC-006**: Exibição de troféus: em 100% das trocas de modo, o ícone exibido corresponde ao asset do modo (`trofeu-relaxante/normal/desafio.png`) na dimensão de 32 px prevista (desvio de 0 px), com contador e progresso "k/4" do modo correto — 0 misturas de progresso entre modos.
- **SC-007**: Disponibilidade dos obstáculos: Normal e Desafio com os dois obstáculos ativos na 1ª corrida em 100% dos casos; Relaxante com 0 obstáculos ativos antes do 1º troféu e os dois ativos de forma permanente após ele em 100% dos casos; 0 desbloqueios no Relaxante causados por troféus de outros modos; desbloqueio mantido após reinício em 100% das verificações.
- **SC-008**: Efeitos dos obstáculos: em 100% das colisões de referência, o efeito correspondente é aplicado e termina dentro da duração configurada com tolerância ≤ 10%; 0 efeitos permanentes após o término; 0 alterações de combustível atribuídas a obstáculos; 0 empilhamentos de intensidade em colisões repetidas durante um efeito.
- **SC-009**: Detecção em alta velocidade: no modo Desafio, 0 atravessamentos sem ativação do efeito em 100 encontros de referência por obstáculo; 0 obstáculos fora dos limites da pista, 0 bloqueios totais da passagem e 0 nascimentos sobre veículos.
- **SC-010**: Persistência: sem dados salvos → 100% dos valores padrão carregados com 0 falhas; arquivo ausente ou inválido → 0 travamentos e 0 perdas de dados válidos; após conquistas, reiniciar restaura 100% de recordes, troféus, ciclos e desbloqueio sem duplicação (0 registros, pontos ou troféus a mais).
- **SC-011**: Registro de resultados: 100% das vitórias geram exatamente 1 resultado e 0 corridas perdidas geram resultado (conforme Q2-B); o histórico não acumula entradas duplicadas da mesma corrida após voltas ao menu ou reinícios.
- **SC-012**: Regressão e integridade: a suíte automatizada existente permanece 100% verde após a implementação (0 regressões em movimentação, colisão, combustível, progressão, ambientes, estados, dificuldade e áudio); execução completa sem erros de console nem referências inválidas de recursos; novos elementos de interface legíveis e sem sobreposição em 100% das resoluções suportadas.

## Assumptions

- **Decisão Q1 (2026-10-17)**: a derrota zera o progresso do ciclo de troféus do modo vigente (espelhando o reset de ciclo da SPEC-009), preservando o total de troféus conquistados.
- **Decisão Q2 (2026-10-17)**: somente vitórias registram resultado e podem atualizar recordes; o Fim de Jogo não gera registro — por isso a pontuação recompensa a distância em corridas vencidas.
- A pontuação da corrida que completa um ciclo considera os troféus do modo **já incluindo** o troféu conquistado na própria corrida, calculada em um único momento do encerramento (sem pontos duplicados).
- **Persistência**: não existe hoje nenhum mecanismo de persistência no projeto — a progressão atual é só de sessão; esta spec introduz o serviço central de gravação/carga de dados.
- A **pontuação acumulada por modo** é a soma das pontuações dos resultados registrados daquele modo; é rastreada, persistida e **exibida no menu e nas telas de fim junto do recorde** (decisão de 2026-10-17, opção A).
- **Data e hora** do resultado são gravadas quando a plataforma disponível permitir (RF-001: "quando compatível"); a ausência não invalida o registro.
- **Exibição**: os novos elementos (pontuação da corrida, recorde, ícone/quantidade/progresso de troféus, desbloqueio) aparecem **no menu e nas telas de vitória/Fim de Jogo**, no formato visual que melhor se integrar à UI existente — contagem e progresso devem permanecer claros; **durante a corrida não há nenhum elemento novo** (decisão de exibição de 2026-10-17, opção A).
- Os **cinco assets já existem** no projeto nas pastas de assets do projeto (`assets/trofeus/` e `assets/obstaculos/`) com as dimensões previstas (32×32 os três troféus; 48×35 a poça; 48×27 o cascalho); não devem ser recriados — a localização exata é confirmada na inspeção antes da configuração dos caminhos.
- Os obstáculos atuam **apenas sobre o veículo do jogador** (RF-005/RF-006): NPCs não são afetados e a decoração continua sem colisão; a colisão jogador×NPC e suas derivas/penalidades permanecem intocadas.
- Efeitos de obstáculo são **independentes** da deriva de colisão com NPCs (não a substituem nem a anulam) e não têm interação com combustível.
- Enquanto o efeito de um obstáculo está ativo durante a pausa, ele não avança (congelado junto com o resto do jogo).
- A **distribuição** dos obstáculos obedece a frequência/quantidade configuráveis, no mesmo espírito da geração existente de galões/decoração, sem sobreposição com outros obstáculos e sem fechar a pista.
- Os **valores iniciais dos pesos** da pontuação, dos efeitos e da distribuição são pontos de balanceamento inicial, definidos na configuração central e calibrados durante os testes integrados/aceite — a spec fixa as regras, não os números.
- O **histórico de resultados** pode ter limite configurável de entradas para evitar crescimento indefinido (coerente com o princípio de performance da constituição).
- Fora de escopo (conforme §7 da especificação do usuário): recriar sistemas existentes, segundo sistema de progressão/combustível/colisão, misturar progresso dos modos, efeitos permanentes de obstáculo, penalizar consumo normal, armas/multiplayer/RPG, alterar os multiplicadores da SPEC-009 e modificar os fluxos de início/chegada/vitória/derrota/combustível.
