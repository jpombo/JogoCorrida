# Feature Specification: Sistema de Trânsito e Decoração dos Ambientes

**Feature Branch**: `004-traffic-and-decoration`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "SPEC-004 — Sistema de Trânsito e Decoração dos Ambientes. Implementar os elementos móveis e decorativos que compõem a experiência visual da pista: veículos de trânsito (carros e caminhões) e decoração lateral específica de cada ambiente. Os dois sistemas devem ter responsabilidades independentes (TrafficSystem e DecorationSystem) e não devem implementar colisões. O trânsito deve ter spawn, movimento relativo à velocidade do jogador, despawn e reaproveitamento de objetos, posicionado apenas em faixas válidas e funcional durante as transições de 2 para 4 e de volta a 2 vias. A decoração deve usar a biblioteca de assets do ambiente atual (Planície, Deserto, Floresta, Gelo), ser distribuída nos dois lados da estrada fora da área trafegável, acompanhar o deslocamento da pista e ser reciclada. A ordem visual deve ser Background, Decoração, Estrada, Trânsito, Jogador e Interface. Pré-requisitos: SPEC-001, SPEC-002 e SPEC-003."

---

## User Scenarios & Testing

### User Story 1 - Verificar Veículos de Trânsito em Movimento na Estrada (Priority: P1)

O jogador dirige e visualiza outros veículos entrando na tela pelo topo, sempre criados fora da área visível. Enquanto o jogador mantém a aceleração, os veículos são ultrapassados e descem em direção à parte inferior da tela até serem removidos. Quando o jogador reduz a velocidade e para, os veículos visibles mantêm o próprio deslocamento normal e sobem em direção ao topo da tela até ficarem invisíveis. Nenhum dos dois casos permite crescimento indefinido de objetos durante uma partida longa.

**Por que esta prioridade**: O trânsito é o principal elemento novo de tensão visual da pista. Sem ele a estrada permanece um corredor vazio e a sensação de jogo de corrida se perde. É a fatia mínima que já entrega valor.

**Teste Independente**: Pode ser testado iniciando o jogo, acelerando e observando o surgimento, o deslocamento e o desaparecimento de veículos na estrada, sem que nenhum veículo seja criado dentro da área visível ou fora das faixas.

**Cenários de Aceitação**:

1. **Dado** que o jogo está em andamento com o trânsito habilitado, **Quando** o jogador acelera, **Então** veículos de trânsito entram na área visível pelo topo da tela.
2. **Dado** que existem veículos de trânsito visíveis, **Quando** o jogador mantém a aceleração, **Então** o jogador os ultrapassa e eles descem em direção à parte inferior da tela.
3. **Dado** que o jogador mantém a aceleração, **Quando** um veículo de qualquer categoria ultrapassado sai da área do jogo pela parte inferior, **Então** ele é marcado para remoção e desaparece da cena.
4. **Dado** que existem veículos de trânsito visíveis, **Quando** o jogador deixa de acelerar e reduz a velocidade, **Então** os veículos mantêm o próprio deslocamento normal e sobem em direção ao topo da tela.
5. **Dado** que o jogador está parado, **Quando** um veículo sobe até sair completamente da área visível pelo topo, **Então** ele deixa de ser exibido e é disponibilizado novamente para reutilização.
6. **Dado** que existem veículos de trânsito, **Quando** o jogador se desloca lateralmente, **Então** os veículos se deslocam longitudinalmente, mantendo-se dentro da área trafegável.
7. **Dado** que o jogo está em execução por tempo prolongado, **Quando** observo a quantidade de veículos, **Então** ela permanece limitada ao máximo configurado e não cresce de forma indefinida.
8. **Dado** que o jogador está em qualquer velocidade, **Quando** um veículo de trânsito é criado, **Então** ele surge acima da área visível, dentro das faixas válidas da estrada naquela altura, e nunca aparece de repente sobre o veículo do jogador.
9. **Dado** que a estrada muda entre 2 e 4 vias, **Quando** um veículo é criado acima da área visível, **Então** ele é posicionado respeitando a largura vigente naquele ponto e permanece dentro da área trafegável durante a transição.

---

### User Story 2 - Distinguir as Categorias de Veículos de Trânsito (Priority: P1)

O jogador identifica visualmente as quatro categorias de veículos no tráfego: `caminhao`, `esporte`, `passeio` e `utilitario`. Cada categoria tem aparência, dimensões e velocidade máxima próprias — 90 km/h para `caminhao` e `utilitario`, 100 km/h para `passeio` e 120 km/h para `esporte`, sempre abaixo dos 125 km/h do jogador. Cada categoria aparece com a frequência definida em configuração.

**Por que esta prioridade**: A variedade visual do tráfego é o que torna a pista crível. Um tráfego formado apenas por veículos iguais é visualmente monótono. As categorias também são a base para as mecânicas de colisão do SPEC-005.

**Teste Independente**: Pode ser testado observando o tráfego durante a condução e confirmando a presença das quatro categorias com aparências, dimensões e velocidades distintas, e que a proporção de cada categoria respeita a configuração.

**Cenários de Aceitação**:

1. **Dado** que o trânsito está habilitado, **Quando** veículos são gerados, **Então** a combinação das quatro categorias aparece na estrada conforme a frequência configurada para cada uma.
2. **Dado** que um veículo é observado, **Quando** consulto sua identificação, **Então** é possível saber a qual categoria ele pertence: `caminhao`, `esporte`, `passeio` ou `utilitario`.
3. **Dado** que a frequência de uma categoria é configurada, **Quando** essa frequência é reduzida, **Então** a proporção daquela categoria na pista diminui proporcionalmente, sem afetar as demais.
4. **Dado** que um veículo de `esporte` é exibido, **Quando** o observo na tela, **Então** ele se distingue dos veículos das outras categorias por aparência e por dimensões.
5. **Dado** que um veículo de `caminhao` é exibido, **Quando** o observo na tela, **Então** ele possui dimensões maiores que as de um `passeio` e não se confunde com ele.
6. **Dado** que a frequência de uma categoria é alterada por configuração, **Então** nenhum código do jogo precisa ser alterado para que a nova proporção passe a valer.
5. **Dado** que o jogador atinge a velocidade máxima, **Quando** observo os veículos de trânsito, **Então** eles continuam se deslocando para baixo em relação à tela, nunca na direção contrária.

---

### User Story 3 - Manter o Trânsito Válido Durante as Transições de Estrada (Priority: P1)

O jogador dirige durante as transições entre a estrada de 2 vias e a de 4 vias. Nenhum veículo de trânsito aparece fora da área trafegável, nenhum veículo fica sobreposto a outros e o trânsito continua funcionando normalmente antes, durante e depois de cada transição.

**Por que esta prioridade**: A estrada já implementa mudanças de largura e de limites. Se o trânsito quebrar nessas transições, veículos aparecerão flutuando sobre o cenário ao lado da estrada, o que torna o jogo visualmente quebrado e é a regressão mais provável desta feature.

**Teste Independente**: Pode ser testado percorrendo a sequência completa 2 vias, expansão, 4 vias, redução e retorno a 2 vias, verificando que nenhum veículo aparece fora da estrada e que o trânsito continua coerente.

**Cenários de Aceitação**:

1. **Dado** que a estrada possui 2 vias, **Quando** veículos de trânsito são gerados, **Então** todos aparecem dentro dessas 2 faixas.
2. **Dado** que a estrada está em transição de 2 para 4 vias, **Quando** veículos de trânsito são gerados ou se deslocam, **Então** todos permanecem dentro da área trafegável, incluindo a largura em transição.
3. **Dado** que a estrada possui 4 vias, **Quando** veículos de trânsito são gerados, **Então** todos aparecem dentro das 4 faixas.
4. **Dado** que a estrada está em transição de 4 para 2 vias, **Quando** veículos de trânsito são gerados ou se deslocam, **Então** todos permanecem dentro da área trafegável.
5. **Dado** que existem múltiplos veículos na estrada, **Quando** observo o tráfego, **Então** nenhum veículo se sobrepõe imediatamente a outro, respeitando o espaçamento mínimo configurado.
6. **Dado** que um veículo ocupa uma faixa que deixa de existir na redução de 4 para 2 vias, **Quando** a transição acontece, **Então** o veículo é reposicionado continuamente para a faixa válida mais próxima, sem desaparecer nem reaparecer na tela.

---

### User Story 4 - Visualizar Decoração Lateral Correspondente ao Ambiente (Priority: P2)

O jogador conduz por uma pista ladeada por elementos decorativos coerentes com o ambiente atual: árvores, casas, feno, milho e silos na Planície; cactos, árvores, dunas e casas no Deserto; árvores, lagos e serra na Floresta; árvores, casas e bonecos de neve no Gelo. A decoração aparece nos dois lados da estrada e nunca invade a área onde o jogador dirige.

**Por que esta prioridade**: É o segundo pilar da feature e o que transforma a pista em um lugar com identidade. Depende do SPEC-003 e pode ser entregue depois do trânsito, ainda entregando valor isolado.

**Teste Independente**: Pode ser testado selecionando cada um dos quatro ambientes e verificando que a decoração exibida pertence exclusivamente à biblioteca daquele ambiente, que aparece dos dois lados da estrada e que não invade a área trafegável.

**Cenários de Aceitação**:

1. **Dado** que o ambiente Planície está ativo, **Quando** observo as laterais da estrada, **Então** vejo elementos da biblioteca da Planície, como árvores, casas, feno, milho e silos.
2. **Dado** que o ambiente Deserto está ativo, **Quando** observo as laterais da estrada, **Então** vejo elementos da biblioteca do Deserto, como cactos, árvores, dunas e casas.
3. **Dado** que o ambiente Floresta está ativo, **Quando** observo as laterais da estrada, **Então** vejo elementos da biblioteca da Floresta, como árvores, lagos e serra.
4. **Dado** que o ambiente Gelo está ativo, **Quando** observo as laterais da estrada, **Então** vejo elementos da biblioteca do Gelo, como árvores, casas e bonecos de neve.
5. **Dado** que qualquer ambiente está ativo, **Quando** observo a tela, **Então** existem elementos decorativos nos dois lados da estrada.
6. **Dado** que elementos decorativos estão exibidos, **Quando** meço a distância entre eles e a borda da área trafegável, **Então** ela é maior ou igual à margem de segurança configurada.
7. **Dado** que qualquer ambiente está ativo, **Quando** observo a tela, **Então** não aparece nenhum elemento decorativo pertencente a outro ambiente.
8. **Dado** que a decoração está exibida em um dos lados, **Quando** observo a lateral, **Então** os elementos se distribuem em mais de uma profundidade, das mais próximas às mais distantes da estrada.

---

### User Story 5 - Acompanhar a Decoração com o Movimento da Estrada (Priority: P2)

O jogador percebe que a decoração se desloca junto com a estrada, acelerando e freando junto com o veículo, sem saltos ou cortes visíveis. Os elementos são criados acima da área do jogo, tendem para a parte inferior da tela conforme o carro avança e, ao ficarem completamente invisíveis, são removidos da cena dando lugar a novas decorações, mantendo o consumo de memória sob controle. Com o jogador parado, nada se move.

**Por que esta prioridade**: Decoração estática denuncia falha de integração visual. É o requisito que faz a composição parecer contínua, mas só tem sentido depois que a decoração existe.

**Teste Independente**: Pode ser testado acelerando e freando e observando que a decoração acompanha o deslocamento da estrada, e conduzindo por tempo prolongado para verificar que as laterais continuam povoadas.

**Cenários de Aceitação**:

1. **Dado** que a decoração está exibida, **Quando** o jogador acelera, **Então** a decoração se desloca para baixo em relação à tela, acompanhando o deslocamento da estrada.
2. **Dado** que a decoração está em movimento, **Quando** o jogador freia até parar completamente, **Então** nenhum elemento decorativo se desloca.
3. **Dado** que a decoração está sendo repovoada, **Quando** um novo elemento é incluído, **Então** ele é criado acima da área do jogo e só se torna visível ao entrar na tela.
4. **Dado** que um elemento decorativo se torna completamente invisível para o jogador, **Quando** isso ocorre, **Então** ele é marcado para remoção e some da cena, dando lugar a novas decorações, sem que a lateral fique vazia por um período perceptível.
5. **Dado** que o jogo está em execução por tempo prolongado, **Quando** observo a quantidade de elementos decorativos, **Então** ela permanece limitada e não cresce de forma indefinida.
6. **Dado** que a decoração está sendo criada acima da área do jogo, **Quando** um elemento é posicionado, **Então** ele já nasce fora da área da estrada, respeitando a margem de segurança.
7. **Dado** que existem elementos decorativos em mais de uma profundidade, **Quando** observo as laterais da estrada, **Então** agrupamentos visuais entre elementos são aceitos como parte da composição, sem que nenhum elemento alcance a área trafegável.
8. **Dado** que o trânsito e a decoração estão ativos ao mesmo tempo, **Quando** o jogo é executado por um período prolongado, **Então** a taxa de quadros por segundo permanece estável, sem quedas recorrentes de desempenho.

---

### User Story 6 - Trocar a Decoração ao Mudar de Ambiente (Priority: P3)

Ao mudar de ambiente, a lateral da estrada passa a exibir apenas os elementos do novo ambiente, sem exigir alteração de código e sem deixar resíduo do ambiente anterior na tela.

**Por que esta prioridade**: A troca dinâmica de ambiente não é decidida pelo jogador nesta fase, mas o sistema precisa estar correto caso a troca seja realizada por configuração ou por uma fase futura.

**Teste Independente**: Pode ser testado alternando a configuração de ambiente e verificando que, após a troca, somente a biblioteca do novo ambiente aparece nas laterais.

**Cenários de Aceitação**:

1. **Dado** que o ambiente Planície está ativo com sua decoração exibida, **Quando** o ambiente é alterado para Floresta, **Então** as laterais passam a exibir somente elementos da Floresta.
2. **Dado** que um ambiente está ativo, **Quando** consulto a biblioteca em uso, **Então** ela corresponde exatamente ao ambiente atual.
3. **Dado** que a troca de ambiente ocorre, **Quando** observo a tela após a troca, **Então** não resta nenhum elemento do ambiente anterior.

---

### User Story 7 - Ajustar a Experiência Visual por Configuração (Priority: P3)

O responsável pelo ajuste do jogo consegue alterar a quantidade de veículos, a frequência de cada categoria de veículo, a densidade e o tamanho da decoração, a margem de segurança e a diferença de velocidade entre as camadas, sem alterar o código do jogo. Esses mesmos parâmetros ficam disponíveis para serem ajustados futuramente por nível de dificuldade.

**Por que esta prioridade**: É um requisito de ajuste e de preparação para o SPEC-008, mas não muda a experiência do jogador final se entregue por último.

**Teste Independente**: Pode ser testado alterando os valores de configuração e verificando que o resultado visual muda de acordo com eles, sem necessidade de modificação de código.

**Cenários de Aceitação**:

1. **Dado** que a densidade de decoração é alterada, **Quando** o jogo é executado, **Então** a quantidade de elementos nas laterais muda conforme o novo valor.
2. **Dado** que a margem de segurança é alterada, **Quando** o jogo é executado, **Então** a distância entre a decoração e a borda da área trafegável muda conforme o novo valor.
3. **Dado** que o multiplicador de velocidade da decoração é alterado, **Quando** o jogo é executado, **Então** a diferença de velocidade entre a decoração e a estrada muda conforme o novo valor.
4. **Dado** que o trânsito pode ser desabilitado por configuração, **Quando** o trânsito está desabilitado, **Então** nenhum veículo novo é criado e a decoração e a estrada continuam funcionando normalmente.
5. **Dado** que a dificuldade progressiva ainda não existe, **Quando** consulto os parâmetros de trânsito e decoração, **Então** eles estão disponíveis e podem ser recebidos externamente quando a dificuldade for implementada.

---

### User Story 8 - Preservar o Funcionamento das Features Anteriores (Priority: P1)

O jogador continua com todos os controles e comportamentos das etapas anteriores funcionando: aceleração, frenagem e movimentação lateral do veículo (SPEC-001), deslocamento contínuo da estrada com transições entre 2 e 4 vias (SPEC-002) e os quatro ambientes com seus respectivos cenários (SPEC-003), agora com trânsito e decoração sobrepostos.

**Por que esta prioridade**: Regressão em qualquer etapa anterior torna o jogo injogável e anula o valor entregue por esta feature. É requisito de aceite, não um item opcional.

**Teste Independente**: Pode ser testado executando o jogo com trânsito e decoração ativos e validando todos os comportamentos anteriores em cada um dos quatro ambientes.

**Cenários de Aceitação**:

1. **Dado** que o trânsito e a decoração estão ativos, **Quando** o jogador acelera, freia e se desloca para esquerda e direita, **Então** o veículo responde exatamente como antes desta feature.
2. **Dado** que o trânsito e a decoração estão ativos, **Quando** a pista se desloca, **Então** o deslocamento da estrada e a transição entre 2 e 4 vias ocorrem normalmente.
3. **Dado** que o trânsito e a decoração estão ativos, **Quando** cada um dos quatro ambientes é utilizado, **Então** o cenário correspondente é exibido corretamente.
4. **Dado** que o veículo do jogador se desloca lateralmente, **Quando** ele alcança os limites da estrada, **Então** ele é contido dentro da área trafegável, sem que a decoração ou o trânsito interfiram nessa contenção.
5. **Dado** que o jogo é executado com trânsito e decoração ativos, **Quando** observo a composição final, **Então** o cenário ao fundo, a decoração lateral, a estrada, o trânsito, o veículo do jogador e a interface aparecem na ordem correta, sem sobreposições indevidas.

---

### Edge Cases

- **Biblioteca de decoração vazia ou asset ausente**: se um ambiente não tiver nenhum asset de decoração disponível, a lateral fica sem elementos decorativos, o jogo permanece jogável e um aviso é registrado. O trânsito, a estrada e o jogador continuam funcionando normalmente.
- **Biblioteca com um único asset**: se o ambiente possuir apenas um asset de decoração, esse asset se repete em sequência, pois não há alternativa possível; a repetição não deve ser tratada como falha. O limite de 10 ocorrências consecutivas por lado previsto para os elementos `repeatable` (FR-036) também se aplica nesse caso.
- **Repetição consecutiva de elementos de árvore**: os elementos com `repeatable == true` na configuração (nas bibliotecas atuais, os 6 assets `arvore`) podem se repetir consecutivamente até 10 vezes em um mesmo lado da estrada, somando todas as profundidades desse lado e formando agrupamentos naturais de floresta. Ao atingir o limite, o sistema volta a evitar a repetição imediata. Os demais elementos nunca se repetem consecutivamente enquanto houver alternativa na biblioteca.
- **Espaço longitudinal insuficiente para o espaçamento mínimo**: se não houver espaço suficiente ao longo da direção de deslocamento para respeitar o espaçamento mínimo entre veículos ou entre elementos decorativos, nenhum novo objeto é criado naquele instante, em vez de permitir sobreposição ao longo dessa direção. Isso não impede a sobreposição visual na direção lateral, que é permitida. Exceção do ajuste de 2026-10-05: durante a reposição abaixo da densidade mínima (FR-063) o nascimento ocorre logo acima da área visível e a exigência passa a ser a separação retangular mínima (FR-019); o espaçamento longitudinal completo permanece para o fluxo normal.
- **Faixa da velocidade ocupada no nascimento**: se a faixa lateral reservada da velocidade da categoria (FR-065) não tiver espaço para a separação retangular na altura de criação, o nascimento é adiado para o instante seguinte e sorteado de novo (com categoria nova), em vez de ocupar a faixa de outra velocidade ou nascer fora da faixa; a fila de nascimento pode crescer temporariamente até os veículos da faixa descerem o suficiente, sem nunca gerar sobreposição ou comboio.
- **Velocidade zero**: com o jogador completamente parado, a decoração não se desloca e os elementos já visíveis permanecem congelados, sem criação nem remoção. O trânsito para de receber novos veículos e, como os veículos são criados fora da área visível, nenhum deles pode aparecer sobre o jogador. O jogador que retome o movimento retoma também a criação e a reciclagem da decoração.
- **Veículo mais rápido que a velocidade atual do jogador**: como a velocidade do jogador pode ficar abaixo da velocidade de um veículo já em cena, esse veículo sobe em direção ao topo da tela em vez de descer. Ao cruzar a borda superior, é marcado para remoção. O sistema não pode presumir que todo veículo sempre desce.
- **Margem estreita entre `esporte` e o jogador**: a categoria `esporte` (120 km/h) é a mais rápida do trânsito e fica a apenas 5 km/h da velocidade máxima do jogador (125 km/h). Nessa faixa, o veículo de `esporte` desce em relação à tela muito lentamente, e o jogador só o ultrapassa após percorrer uma distância significativa. Esse comportamento é esperado e não é falha; se a ultrapassagem ficar perceptível como travamento na prática, a margem deve ser ampliada por ajuste das velocidades de categoria, e não por alteração do deslocamento relativo.
- **Inversão da direção relativa durante a condução**: um mesmo veículo pode descer enquanto o jogador é mais rápido e passar a subir no mesmo instante em que o jogador reduz a velocidade abaixo da velocidade do veículo. A troca de direção é imediata e não deixa o veículo parado sobre a tela.
- **Veículo parado sobre a borda da tela**: um veículo cuja posição fique exatamente na borda não é removido enquanto ainda houver qualquer pixel visível; a remoção ocorre somente quando estiver completamente fora da área visível.
- **Spawn sem faixa válida acima da área visível**: se, na altura de criação, não houver faixa livre válida (por exemplo, durante um trecho de transição em que a largura disponível é insuficiente para o veículo), a criação é adiada até existir faixa válida, sem criar o veículo sobre a borda da estrada.
- **Espaço lateral insuficiente para múltiplas profundidades**: se a largura disponível em um dos lados não comportar todas as profundidades de decoração, o sistema usa apenas as profundidades que cabem, em vez de invadir a área trafegável.
- **Sobreposição visual entre elementos decorativos**: elementos de profundidades próximas podem se sobrepor parcialmente na direção lateral, formando agrupamentos naturais. Essa sobreposição é visual e esperada; o que nunca pode ocorrer é um elemento sobre a área trafegável ou dentro da margem de segurança.
- **Elemento decorativo maior que a profundidade disponível**: se um elemento for maior que a profundidade na qual foi sorteado, ele é deslocado para a profundidade mais distante que o comporte, preservando a margem de segurança.
- **Múltiplas trocas de ambiente**: após alternar repetidamente entre ambientes, apenas a biblioteca do ambiente vigente fica em uso, sem acúmulo de elementos do ambiente anterior.
- **Desabilitar o trânsito em tempo de execução**: com o trânsito desabilitado, os veículos já existentes seguem seu movimento normal e saem da área útil por conta própria; a desativação não congela a tela.
- **Desabilitar a decoração em tempo de execução**: com a decoração desabilitada, os elementos existentes deixam de ser exibidos e o restante do jogo continua funcionando.
- **Densidade configurada acima da capacidade da tela**: se a densidade configurada for superior à capacidade de exibição, o sistema respeita o limite de elementos ativos, distribuindo o excedente nas profundidades disponíveis em vez de aumentar a quantidade de elementos ativos.
- **Conjunto reutilizável esgotado**: se um novo veículo ou elemento decorativo for devido e não houver mais objetos disponíveis para reutilização, um novo objeto é criado naquele instante e passa a integrar o conjunto, sem violar o limite configurado de objetos ativos e sem repetir na tela um elemento já existente.
- **Veículo mais largo que a faixa em transição**: se durante uma redução o veículo ocupar praticamente toda a largura disponível, ele permanece dentro dos limites atuais da estrada e não invade a decoração.
- **Reatribuição de faixa durante o estreitamento**: quando um veículo precisa mudar de faixa porque a sua deixou de existir, ele acompanha o limite que está se movendo em vez de saltar de uma faixa para outra de uma vez. Se naquele instante não houver faixa próxima que comporte a largura do veículo, ele aguarda o espaço disponível sem ficar sobre a área que deixou de ser trafegável, sem ser removido e sem reaparecer.

---

## Requirements

### Sistema de Trânsito

- **FR-001**: O sistema de trânsito deve suportar, nesta versão, quatro categorias de veículo: `caminhao`, `esporte`, `passeio` e `utilitario`. Cada veículo de trânsito pertence a exatamente uma dessas categorias.
- **FR-002**: Cada veículo de trânsito deve expor, no mínimo: tipo, posição, velocidade, direção, faixa (posição lateral na estrada) e estado.
- **FR-003**: Os estados de um veículo de trânsito nesta versão são Active e Inactive. Estados relacionados a colisão, dano ou destruição não devem existir.
- **FR-004**: A criação de veículos deve ocorrer por um mecanismo de spawn configurável, com parâmetros para habilitação, quantidade máxima de veículos ativos, distância de spawn e intervalo entre spawns.
- **FR-005**: O sistema não deve gerar veículos de forma contínua e ilimitada. A quantidade de veículos ativos deve respeitar o limite máximo configurado.
- **FR-006**: Os veículos de trânsito devem se deslocar sempre no mesmo sentido de percurso do jogador, nunca em sentido contrário. A posição aparente de um veículo na tela é determinada pela diferença de velocidade com o jogador (FR-007).
- **FR-007**: O deslocamento aparente de um veículo de trânsito na tela deve ser determinado pela diferença entre a velocidade atual do jogador e a velocidade do próprio veículo. Enquanto a velocidade do jogador for maior que a do veículo, o jogador o ultrapassa e o veículo desce na direção à parte inferior da tela. Se a velocidade do jogador for menor que a do veículo, o veículo mantém o seu próprio deslocamento normal e sobe em direção ao topo da tela, até deixar a área visível.
- **FR-008**: A velocidade máxima de qualquer veículo de trânsito deve ser sempre inferior à velocidade máxima do jogador, fixada em 125 km/h. A categoria mais rápida do trânsito é `esporte`, com 120 km/h, o que preserva a ultrapassagem com margem de 5 km/h. Portanto, ao atingir a velocidade máxima o jogador ultrapassa todos os veículos de trânsito, que saem pela parte inferior da tela. Nenhum veículo de trânsito pode ser mais rápido que o jogador em sua velocidade máxima. A arquitetura deve permitir veículos em sentido contrário no futuro, mas o sistema não deve gerar veículos em sentido contrário enquanto a estrada for de sentido único.
- **FR-009**: Os veículos de trânsito devem ser posicionados exclusivamente dentro das faixas válidas da estrada. Nenhum veículo pode ser criado ou permanecer fora da área trafegável.
- **FR-010**: A seleção da categoria do veículo deve ser feita por parâmetro configurável de frequência por categoria, aplicado a `caminhao`, `esporte`, `passeio` e `utilitario` de forma independente.
- **FR-011**: Cada categoria de veículo deve ser uma categoria distinta, possuindo identificação própria, aparência própria e configurável, dimensões próprias, velocidade máxima própria e posicionamento em faixa. A velocidade máxima é uma característica da categoria, não de cada veículo individual: todos os veículos de `caminhao` e `utilitario` têm 90 km/h, todos os de `passeio` têm 100 km/h e todos os de `esporte` têm 120 km/h. O veículo do jogador tem 125 km/h.
- **FR-012**: Os assets visuais dos veículos de trânsito devem ser configuráveis por categoria. A lógica de trânsito não deve depender do nome físico dos arquivos de imagem: cada categoria referencia uma pasta de assets, e a troca ou a inclusão de assets dentro dessa pasta não deve exigir alteração de código. O mapeamento entre categoria, pasta de assets e velocidade máxima deve ser centralizado em um único lugar, acessível pelo identificador da categoria.

As categorias e suas velocidades máximas estão definidas na relação abaixo. A pasta de cada categoria é a fonte exclusiva dos seus assets visuais.

| Categoria | Velocidade máxima | Pasta de assets | Assets | Dimensão |
| --- | --- | --- | --- | --- |
| `caminhao` | 90 km/h | `assets/npcs/caminhao/` | `caminhao_madeireiro` | 32x128 |
| `esporte` | 120 km/h | `assets/npcs/esporte/` | `carro-amarelo`, `carro-laranja`, `carro-verde` | 32x64 |
| `passeio` | 100 km/h | `assets/npcs/passeio/` | `carro_01`, `carro_02`, `carro_04`, `carro_07`, `carro_09`, `carro_10` | 32x64 |
| `utilitario` | 90 km/h | `assets/npcs/utilitario/` | `Carro-prata`, `carro_03`, `carro_05`, `carro_06`, `carro_08`, `carro_11`, `carro_12` | 32x64 |
| Jogador | 125 km/h | `assets/player/` | `azul`, `vermelho` | — |

- **FR-013**: Todo veículo de trânsito deve ser criado acima da área visível do jogo e nunca dentro dela, de modo que nenhum veículo apareça de forma abrupta sobre a tela ou sobre o veículo do jogador.
- **FR-014**: A posição de criação de um veículo deve estar dentro das faixas válidas da estrada na altura em que o veículo é criado, respeitando a largura vigente naquele ponto, inclusive quando a área acima da tela corresponder a um trecho de 2 vias e a parte visível a um trecho de 4 vias (ou vice-versa) durante uma transição. A criação só ocorre quando existe faixa válida livre, respeitando o espaçamento mínimo.
- **FR-015**: Um veículo que for ultrapassado pelo jogador e sair da área útil pela parte inferior da tela deve ser marcado para remoção, desativado, ter seus recursos liberados e ser disponibilizado para reutilização, e não simplesmente ocultado.
- **FR-016**: Um veículo cuja velocidade for maior que a velocidade atual do jogador sobe em direção ao topo da tela e, ao deixar completamente a área visível por essa borda, também deve ser marcado para remoção, desativado e disponibilizado para reutilização.
- **FR-017**: A arquitetura deve priorizar a reutilização de veículos por meio de um conjunto de objetos reutilizáveis, em vez de criar e destruir objetos continuamente.
- **FR-018**: Quando não houver mais veículos disponíveis para reutilização no conjunto de objetos reutilizáveis e a criação de um novo veículo for devida, o sistema deve criar um novo veículo naquele instante e incorporá-lo ao conjunto, em vez de recusar a criação ou exceder o limite configurado de veículos ativos.
- **FR-019**: Deve existir um espaçamento mínimo configurável entre veículos de trânsito, evitando sobreposição imediata e mantendo o tráfego visualmente legível. A separação aplicada no nascimento é retangular mínima configurável (folga lateral **ou** longitudinal), de modo que nenhum veículo nasça sobreposto a outro; o espaçamento longitudinal completo permanece exigido no fluxo normal de criação, e durante a reposição abaixo da densidade mínima (FR-063) a separação retangular é o que vale, com o nascimento sempre fora da área visível. Durante o movimento, o espaçamento longitudinal mínimo entre dois veículos do mesmo corredor lateral nunca pode ser um valor fixo menor que a soma das meias-alturas dos dois veículos mais a separação retangular configurável: o piso efetivo é derivado das alturas das categorias envolvidas, de modo que um veículo alto (caminhão) nunca fique visualmente sobreposto ao da frente (ajuste de 2026-10-05).
- **FR-020**: O trânsito deve permanecer funcional durante todo o deslocamento contínuo da estrada e durante toda a transição entre 2 e 4 vias e vice-versa, utilizando sempre as faixas válidas disponibilizadas pelo sistema de estrada.
- **FR-021**: Quando a largura da estrada mudar e a faixa ocupada por um veículo de trânsito deixar de existir, o veículo deve ser reposicionado continuamente para a faixa válida mais próxima, preservando seu tipo, sua velocidade e seu espaçamento em relação aos demais veículos. Nenhum veículo deve permanecer sobre a área que deixou de ser trafegável, e nenhum veículo deve aparecer ou desaparecer da área visível em razão da mudança de largura da estrada.
- **FR-022**: O sistema de trânsito não deve alterar a geometria da estrada, nem seus limites, nem sua configuração de vias.
- **FR-023**: Todos os parâmetros de trânsito devem estar centralizados e ser ajustáveis por configuração, sem exigir alteração de código: habilitação do trânsito, quantidade máxima de veículos ativos, intervalo e distância de spawn, frequência por categoria e espaçamento mínimo entre veículos. A densidade do trânsito é programada de forma conjunta pela quantidade máxima de veículos ativos e pelo intervalo entre spawns, complementada pelos parâmetros explícitos de densidade mínima e faixa de nascimento introduzidos em 2026-10-05 (FR-063/FR-064): densidade mínima na estrada, teto de ativos por nível de dificuldade, intervalo de enchimento, distância e variância do nascimento e distância de reposição — todos configuráveis sem alteração de código. A velocidade de deslocamento é uma característica da categoria, definida em km/h por categoria.
- **FR-024**: Com o trânsito desabilitado, nenhum veículo novo deve ser criado e os sistemas restantes devem continuar funcionando normalmente.
- **FR-025**: O sistema deve disponibilizar a identificação, a posição e a área ocupada por cada veículo de trânsito, deixando essas informações acessíveis ao sistema de colisões do SPEC-005.
- **FR-026**: Nesta versão não deve existir colisão entre o veículo do jogador e os veículos de trânsito.
- **FR-027**: O sistema de trânsito deve consumir a velocidade atual do jogador e as informações de faixa e limites da estrada apenas como dados de entrada, sem assumir o controle desses sistemas.

### Sistema de Decoração

- **FR-028**: O sistema de decoração deve identificar o ambiente atual e carregar a biblioteca de elementos decorativos correspondente a ele.
- **FR-029**: Cada ambiente deve possuir uma biblioteca própria e exclusiva, conforme a relação abaixo.

| Ambiente | Identificador | Dificuldade | Pasta da biblioteca | Elementos |
| --- | --- | --- | --- | --- |
| Planície | `PLAINS` | 1 | `assets/decoracao/planice/` | `planice_arvore01.png`, `planice_casa01.png`, `planice_feno01.png`, `planice_milho.png`, `planice_silo01.png` |
| Deserto | `DESERT` | 2 | `assets/decoracao/deserto/` | `deserto_arvore01.png`, `deserto_arvore02.png`, `deserto_cactus.png`, `deserto_casa.png`, `deserto_duna.png` |
| Floresta | `FOREST` | 3 | `assets/decoracao/floresta/` | `floresta_arvore01.png`, `floresta_arvore02.png`, `floresta_lago.png`, `floresta_serra.png` |
| Gelo | `ICE` | 4 | `assets/decoracao/gelo/` | `gelo_arvore.png`, `gelo_boneco.png`, `gelo_casa01.png` |

- **FR-030**: O mapeamento entre ambiente e biblioteca deve ser centralizado em um único lugar, acessível pelo identificador do ambiente. Não é permitido espalhar condicionais pelo sistema para escolher os assets.
- **FR-031**: A alteração do ambiente deve alterar automaticamente a biblioteca de decoração em uso, sem exigir alteração de código.
- **FR-032**: A decoração deve existir nos dois lados da estrada. Cada elemento decorativo deve registrar a qual lado pertence.
- **FR-033**: Nenhum elemento decorativo pode ocupar a área trafegável. Deve existir uma margem de segurança configurável entre a borda da área trafegável e o elemento decorativo.
- **FR-034**: Em cada lado da estrada, a decoração deve se distribuir em múltiplas profundidades, das mais próximas às mais distantes da área trafegável, de modo a produzir uma composição com sensação de volume. A quantidade de profundidades e o espaçamento entre elas devem ser configuráveis.
- **FR-035**: A decoração não deve bloquear nem interferir no jogador, nos veículos de trânsito, nas faixas da estrada ou nas transições de largura da estrada.
- **FR-036**: A distribuição dos elementos decorativos deve ser variável, evitando sequências repetitivas do mesmo tipo (por exemplo, cinco silos em sequência). O sistema deve evitar a repetição imediata do mesmo elemento sempre que a biblioteca possuir alternativas. Exceção: os elementos decorativos marcados como `repeatable` na configuração — `planice_arvore01`, `deserto_arvore01`, `deserto_arvore02`, `floresta_arvore01`, `floresta_arvore02` e `gelo_arvore` — podem se repetir consecutivamente, com o limite de 10 ocorrências do mesmo elemento em sequência **por lado da estrada**, contando todos os elementos desse lado independentemente da profundidade. Todos os demais elementos mantêm a proibição de repetição imediata. A classificação de um elemento como `repeatable` é um dado de configuração e nunca deve ser deduzida do nome do arquivo em tempo de execução. A escolha entre os candidatos elegíveis é ponderada pelo **percentual de apresentação** declarado em cada entrada da biblioteca (em pontos percentuais que somam 100 por ambiente): em partidas longas a frequência de cada elemento se aproxima do seu percentual declarado, e o sistema compensa internamente o efeito das regras de repetição para que essa aproximação valha mesmo com as regras ativas — o percentual declarado continua sendo o dado de configuração e a referência de conferência. Ressalva mensurável: numa biblioteca com uma única árvore repetível, o limite de 10 seguidas impõe teto de cerca de 90,9% para a frequência observada dessa árvore; em Gelo, onde a árvore é declarada com 96%, a frequência observada se aproxima desse teto, e o excedente reparte-se entre os demais elementos do ambiente.
- **FR-037**: A quantidade de decoração deve ser configurável por um parâmetro de densidade, que pode programar a distância média entre elementos, a quantidade de elementos ativos ou a frequência de geração. A mistura visível de cada ambiente também deve ser configurável elemento a elemento, por um percentual de apresentação declarado na configuração, de modo que a chance de cada elemento nascer seja previsível e alterável sem tocar em código.
- **FR-038**: Os elementos decorativos podem se sobrepor visualmente entre si na direção lateral, formando agrupamentos naturais, desde que nenhum elemento ocupe a área trafegável e a margem de segurança em relação à estrada seja preservada. O espaçamento mínimo e máximo entre elementos aplica-se exclusivamente à direção de deslocamento, e não à posição lateral.
- **FR-039**: A velocidade de deslocamento da decoração deve ser derivada da velocidade de deslocamento da estrada, multiplicada por um fator configurável.
- **FR-040**: A decoração deve acompanhar o deslocamento da estrada, deslocando-se para baixo em relação à tela enquanto o jogador se move. Com o jogador completamente parado, nenhum elemento decorativo se desloca e os elementos já visíveis permanecem congelados na tela, sem serem removidos nem substituídos, até o jogador voltar a se mover.
- **FR-041**: Todo elemento decorativo deve ser criado acima da área visível do jogo e só se tornar visível ao entrar na tela, nunca aparecendo de forma abrupta dentro da área visível. Enquanto o jogador estiver completamente parado, nenhum elemento decorativo novo é criado.
- **FR-042**: A posição lateral de criação de um elemento decorativo, mesmo acima da área visível, deve já estar fora da área trafegável da estrada, respeitando a margem de segurança e a largura vigente naquele ponto. Nenhum elemento decorativo pode ser criado sobre a estrada.
- **FR-043**: Um elemento decorativo que se torne completamente invisível para o jogador por qualquer borda da tela deve ser marcado para remoção, desativado, ter seus recursos liberados e ser disponibilizado para reutilização. O sistema não deve criar elementos de forma indefinida e deve manter o consumo de memória constante durante partidas prolongadas.
- **FR-044**: O sistema de decoração deve priorizar a reutilização de elementos por meio de um conjunto de objetos reutilizáveis, próprio e independente do conjunto de veículos de trânsito, em vez de criar e destruir objetos continuamente.
- **FR-045**: Quando não houver mais elementos decorativos disponíveis para reutilização no conjunto de objetos reutilizáveis e a criação de um novo elemento for devida, o sistema deve criar um novo elemento naquele instante e incorporá-lo ao conjunto, em vez de recusar a criação, duplicar na tela um elemento já existente ou deixar a lateral vazia.
- **FR-046**: Deve ser possível configurar a escala dos elementos decorativos, com o valor padrão igual a 1, e o posicionamento deve considerar as dimensões reais de cada elemento, não supondo que todos os assets tenham o mesmo tamanho. Como os assets de decoração fornecidos são substancialmente maiores que a escala do mundo do jogo, eles devem ser reescalonados na preparação dos arquivos, usando sempre filtro de vizinho mais próximo, e nunca por escala fracionária aplicada sobre o asset original em runtime.
- **FR-047**: Os elementos decorativos devem preservar a identidade visual de pixel art do jogo: sem suavização, sem interpolação e com a proporção original de cada elemento, admitido apenas o ajuste para o encaixe na grade de tiles de 32x32. O reescalonamento dos assets de decoração é feito na preparação dos arquivos com filtro de vizinho mais próximo, e o asset reescalonado é exibido em escala 1.0.
- **FR-048**: A ordem visual da composição deve ser: cenário de fundo, decoração lateral, estrada, veículos de trânsito, veículo do jogador e interface do jogador.
- **FR-049**: Nenhum elemento decorativo deve possuir colisão nesta versão, incluindo entre decoração e jogador, entre decoração e trânsito e entre decorações entre si.
- **FR-050**: O sistema de decoração deve obter do sistema de estrada as informações de limites laterais, área trafegável, posição da estrada e configuração atual de vias.
- **FR-051**: A decoração deve permanecer fora da área trafegável durante todo o percurso das transições entre 2 e 4 vias. Durante a redução de largura, os elementos que se encontram na área que deixa de ser trafegável devem ser reposicionados continuamente para fora da nova área, mantendo a margem de segurança, sem ficarem sobre a estrada e sem serem ocultados de forma abrupta.
- **FR-052**: O sistema de decoração não deve alterar a geometria, os limites ou a configuração da estrada.
- **FR-053**: Em nenhum momento podem ser exibidos simultaneamente elementos de bibliotecas de ambientes diferentes.

### Integração, Configuração e Escopo

- **FR-054**: O sistema de trânsito e o sistema de decoração devem ser independentes, sem dependência direta entre eles. Nenhum dos dois deve controlar o outro.
- **FR-055**: A ordem de atualização dos sistemas deve respeitar a hierarquia: cenário de fundo, decoração, estrada, trânsito e jogador.
- **FR-056**: Todos os parâmetros de decoração devem estar centralizados e ser ajustáveis por configuração, sem exigir alteração de código: habilitação da decoração, densidade, multiplicador de velocidade de deslocamento, espaçamento longitudinal mínimo e máximo entre elementos, quantidade e espaçamento de profundidades, escala dos elementos e margem de segurança em relação à estrada.
- **FR-057**: A densidade da decoração nesta versão é uma configuração puramente visual e não deve ser alterada automaticamente conforme a dificuldade. O SPEC-008 tem permissão para ler e expor `decoration_density`, mas não deve alterá-la automaticamente; qualquer alteração deve ser explícita na difficulty e visível na tela de configuração.
- **FR-058**: O sistema deve permitir uma diferença de velocidade configurável entre as camadas de cenário de fundo, decoração e estrada, mantendo a estrada como referência de 100%. O fator da decoração é introduzido por esta versão (`decoration_speed_multiplier`); o fator do cenário de fundo (`background_multiplier`) já existe desde o SPEC-003 e não é alterado aqui.
- **FR-059**: Cenário de fundo, decoração e estrada devem formar uma composição visual contínua, sem bordas, cortes ou transições abruptas perceptíveis entre as camadas. Verificado com o cenário V9 do quickstart, incluindo aceleração, frenagem e a transição completa de 2 para 4 vias e de volta.
- **FR-060**: Com o sistema de trânsito e o sistema de decoração ativos simultaneamente, o jogo deve manter 60 quadros por segundo como meta de desempenho, aceitando 30 quadros por segundo como piso aceitável, sem quedas de desempenho recorrentes. Para atingir esse objetivo, os dois sistemas devem priorizar a reutilização de objetos e evitar trabalho de alocação por quadro.
- **FR-061**: Os sistemas de trânsito e decoração devem expor externamente seus parâmetros de ajuste (densidade, velocidade, frequência por categoria de veículo, quantidade máxima de veículos, intervalo de spawn e equivalentes de decoração) para que possam ser recebidos por um sistema de dificuldade futuro, sem que a dificuldade seja implementada nesta versão.
- **FR-062**: Esta versão não deve implementar colisões, dano, perda de velocidade por colisão, drift, perda de combustível, fim de jogo, vitória, distância percorrida, checkpoints, dificuldade dinâmica, desbloqueio de níveis, obstáculos decorativos, trânsito em sentido contrário enquanto a estrada for de sentido único, mudança automática de ambiente, efeitos climáticos, ciclo dia/noite, inteligência artificial de veículos, ultrapassagem inteligente, comportamento estratégico de veículos nem pontuação.
- **FR-063**: O trânsito deve manter, durante a condução normal, ao menos a densidade mínima configurada de veículos na estrada junto ao jogador (na tela ou entrando logo acima dela). Quando ficar abaixo desse mínimo, a reposição deve ser imediata — um nascimento por quadro, sempre fora da área visível e respeitando a separação retangular do FR-019 — de modo que o jogador nunca veja um trecho sem veículos depois de ultrapassar o último de um lote. Os parâmetros da reposição (intervalo de enchimento, distância de nascimento e sua variância, distância de reposição) são configuráveis.
- **FR-064**: O teto de veículos ativos (visíveis mais os que já estão a caminho) deve ser definido por nível de dificuldade em configuração, de modo que a quantidade de veículos visíveis nunca ultrapasse o teto do nível vigente. No nível mais difícil (Gelo) o teto é de no máximo 5 veículos visíveis simultâneos. Os valores ficam acessíveis ao sistema de dificuldade futuro (FR-061) e alteráveis sem código.
- **FR-065**: Os nascimentos devem ocorrer em faixas laterais reservadas por velocidade de categoria, derivadas dos limites vigentes da estrada e das velocidades configuradas: cada velocidade distinta ocupa uma faixa fixa (mais rápido à esquerda, mais lento à direita), de modo que velocidades diferentes nunca compartilhem o mesmo corredor lateral. Se a faixa da categoria não estiver livre (separação retangular violada), o nascimento é adiado para o instante seguinte, em vez de ocupar a faixa de outra velocidade. Assim, categorias lentas continuam nascendo com a frequência configurada (FR-010) e o agrupamento em comboio entre velocidades distintas se torna estruturalmente impossível (FR-007, FR-019).

---

### Key Entities

- **Veículo de Trânsito**: Representa um veículo de uma das quatro categorias (`caminhao`, `esporte`, `passeio`, `utilitario`) que ocupa a estrada durante a condução. Possui categoria, posição, velocidade, direção, faixa (posição lateral na estrada) e estado. A velocidade máxima é determinada pela categoria, não pelo asset individual. É identificável e tem área ocupada conhecida, para uso futuro pelo sistema de colisões. Sempre se desloca no mesmo sentido de percurso do jogador, mas sua posição aparente na tela depende da diferença entre a velocidade do jogador e a sua própria.
- **Gerenciador de Trânsito**: Controla a criação, a quantidade, a seleção de tipo, o posicionamento, o deslocamento, a desativação e a reutilização dos veículos de trânsito. Não controla a decoração nem altera a estrada.
- **Elemento Decorativo**: Representa um objeto visual de cenário posicionado fora da área trafegável. Pertence à biblioteca de um ambiente e registra o lado e a profundidade em que está. É criado acima da área do jogo e removido da cena quando se torna completamente invisível.
- **Gerenciador de Decoração**: Controla a identificação do ambiente, o carregamento da biblioteca, a seleção, o posicionamento lateral, o deslocamento, a reciclagem e a reutilização dos elementos decorativos. Não controla o trânsito nem altera a estrada.
- **Biblioteca de Decoração**: Conjunto exclusivo de elementos decorativos associado a um ambiente. É a única fonte de elementos decorativos daquele ambiente.
- **Configuração Visual**: Conjunto centralizado dos parâmetros de ajuste do trânsito e da decoração, incluindo habilitação, densidades, velocidades, espaçamentos, escala e margens.
- **Área Trafegável**: Região da estrada onde o jogador e os veículos de trânsito podem circular, conforme a configuração de vias atual. Serve de referência para posicionar tanto o trânsito quanto a decoração.
- **Ambiente**: Contexto visual em uso, definido pelo SPEC-003, que determina a biblioteca de decoração aplicável e o cenário de fundo.

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Veículos de trânsito são gerados, deslocam-se e desaparecem corretamente durante a condução, com zero veículos criados fora da área trafegável em qualquer um dos quatro ambientes.
- **SC-002**: 100% dos veículos de trânsito e dos elementos decorativos são criados fora da área visível e entram na tela pelo topo, sem qualquer aparição abrupta dentro da área visível.
- **SC-003**: Com o jogador mantendo a aceleração, 100% dos veículos de trânsito são ultrapassados e descem em direção à parte inferior da tela; com o jogador parado ou mais lento que um veículo, 100% dos veículos afetados sobem em direção ao topo da tela. Nenhum veículo permanece parado sobre a tela durante a troca de direção relativa.
- **SC-004**: As quatro categorias de veículo de trânsito (`caminhao`, `esporte`, `passeio`, `utilitario`) são identificáveis visualmente, com dimensões e aparências distintas, e cada uma respeita a proporção definida pela configuração.
- **SC-005**: A quantidade de veículos de trânsito ativos nunca ultrapassa o limite configurado, verificado em partidas contínuas de 10 minutos, sem crescimento indefinido.
- **SC-006**: Verificado em 100% dos quadros de uma partida contínua de 10 minutos: no máximo 2 pares de veículos **no mesmo corredor lateral** (projeções laterais se intersectando — folga lateral negativa entre os retângulos) têm separação longitudinal inferior a `traffic_min_spacing`; veículos em corredores distintos não são contados, pois a sobreposição lateral é permitida (FR-019, FR-065).
- **SC-007**: O trânsito permanece correto durante toda a sequência 2 vias, 4 vias e retorno a 2 vias, sem nenhum veículo fora da área trafegável em nenhum momento da transição.
- **SC-008**: Cada um dos quatro ambientes exibe exclusivamente os elementos de sua própria biblioteca, com 0 ocorrências de elementos de outro ambiente.
- **SC-009**: A decoração é exibida nos dois lados da estrada em 100% do tempo de jogo, distribuída em pelo menos 2 profundidades por lado, com pelo menos 3 elementos visíveis por lado durante a condução normal. As profundidades efetivamente usadas são as que cabem na lateral disponível, e a contagem de elementos visíveis por lado é verificada no cenário V6.
- **SC-010**: 100% dos veículos de trânsito e dos elementos decorativos são removidos da cena assim que se tornam completamente invisíveis, por qualquer borda da tela, verificado em partidas contínuas de 10 minutos sem acúmulo de objetos.
- **SC-011**: Durante a transição de redução de 4 para 2 vias, 100% dos elementos decorativos permanecem fora da área trafegável, reposicionados continuamente e sem oclusão abrupta perceptível.
- **SC-012**: Ao acelerar, ao frear e ao longo da transição de 2 para 4 vias, a decoração e o cenário de fundo acompanham o deslocamento da estrada sem cortes, saltos ou bordas perceptíveis, verificado nos quatro ambientes.
- **SC-013**: A composição final (cenário de fundo, decoração, estrada, trânsito, jogador) permanece visualmente contínua durante toda a condução, sem sobreposição indevida entre camadas e sem elemento decorativo visível sobre a área trafegável.
- **SC-014**: Nenhum elemento decorativo com `repeatable == false` aparece duas vezes consecutivas enquanto a biblioteca tiver alternativas, verificado em 100% das transições de spawn durante uma partida contínua de 10 minutos. Em nenhum momento um mesmo elemento com `repeatable == true` aparece mais de 10 vezes consecutivas **no mesmo lado da estrada**, somando todas as profundidades desse lado.
- **SC-015**: A quantidade de elementos decorativos e de veículos permanece limitada e o consumo de memória é constante durante partidas contínuas de 10 minutos, sem crescimento indefinido de objetos.
- **SC-016**: Todos os parâmetros de trânsito e decoração podem ser ajustados somente por configuração, sem nenhuma alteração de código, e cada alteração produz efeito observável no jogo.
- **SC-017**: Zero regressões: 100% dos comportamentos do SPEC-001, SPEC-002 e SPEC-003 permanecem funcionais com o trânsito e a decoração ativos, verificados nos quatro ambientes.
- **SC-018**: Nenhuma colisão é detectada ou resolvida entre jogador, veículos de trânsito e decoração nesta versão, confirmado pela ausência total de resposta a contato.
- **SC-019**: Todos os parâmetros de ajuste previstos para a dificuldade progressiva estão acessíveis externamente, prontos para serem configurados quando o SPEC-008 for implementado.
- **SC-020**: Os elementos decorativos e os veículos preservam a identidade visual de pixel art, sem suavização; a proporção dos assets de decoração admite somente o ajuste necessário para o encaixe na grade de tiles de 32x32, feito na preparação dos arquivos. O asset de decoração é reduzido ao tamanho do mundo **uma única vez**, na preparação dos arquivos, com filtro de vizinho mais próximo, e é exibido em escala 1.0. A escala fracionária é proibida na preparação dos arquivos; em tempo de execução, `decoration_scale` admite apenas valores iguais a 1.0 nesta versão.
- **SC-021**: Nenhum elemento decorativo ocupa a área trafegável em nenhum dos quatro ambientes, em nenhum momento da criação e em nenhuma transição de largura da estrada.
- **SC-022**: Com o jogador completamente parado por 60 segundos ou mais, 0 elementos decorativos alteram sua posição na tela por quadro, 0 elementos decorativos são criados, 0 elementos decorativos são removidos e nenhum veículo novo de trânsito é criado.
- **SC-023**: Durante a transição de redução de 4 para 2 vias, 0 veículos de trânsito aparecem ou desaparecem da área visível em razão da mudança de largura, e 100% permanecem dentro da área trafegável do início ao fim da transição.
- **SC-024**: Com o trânsito e a decoração ativos simultaneamente nos quatro ambientes, o jogo mantém 60 quadros por segundo como meta e nunca fica abaixo de 30 quadros por segundo de forma recorrente durante partidas contínuas de 10 minutos.
- **SC-025**: Sob configurações de densidade acima do tamanho inicial dos conjuntos reutilizáveis, 100% das criações devidas resultam em objetos válidos, a quantidade de objetos ativos permanece dentro do limite configurado e 0 elementos decorativos duplicados aparecem na tela.
- **SC-026**: Verificado em 100% dos quadros de uma partida contínua de 10 minutos: elementos de uma mesma profundidade respeitam `decoration_spacing_min`; sobreposição visual entre profundidades diferentes não é falha; e 0 elementos são visualizados sobre a área trafegável ou dentro de `decoration_safety_margin`.
- **SC-027**: 100% dos elementos decorativos são exibidos a partir de um asset reescalonado com filtro de vizinho mais próximo, sem interpolação, em escala 1.0, e a altura de cada elemento corresponde a uma fração entre 3% e 35% da altura da área visível (16 px a 160 px numa área visível de 640x480), de modo que todos os elementos dos quatro ambientes sejam visíveis e proporcionais à estrada.
- **SC-028**: Com o jogador na velocidade máxima e após os primeiros 15 s de partida, em pelo menos 95% dos quadros existem ao menos 3 veículos de trânsito na estrada junto ao jogador (FR-063), e em 100% dos quadros a quantidade de veículos ativos respeita o teto configurado do nível de dificuldade — no máximo 5 visíveis simultâneos em Gelo (FR-064).
- **SC-029**: Em 100% dos quadros, um veículo de categoria mais rápida situado em corredor lateral distinto de um mais lento nunca tem sua velocidade reduzida pelo agrupamento: cada veículo em corredor distinto mantém a velocidade própria da categoria (FR-007, FR-011, FR-065), verificado por teste automatizado.
- **SC-030**: Em 100% dos quadros de uma partida contínua, num corredor lateral o veículo mais ao alto nunca tem velocidade de categoria menor que o mais abaixo (colunas ordenadas de baixo para cima), e todo caminhão livre desce à taxa exata da própria categoria — a diferença entre a velocidade da estrada e a da categoria, sem redução por agrupamento. Nenhum comboio arrasta um veículo mais lento à velocidade aparente de um mais rápido (FR-007, FR-065), verificado por teste automatizado.

---

## Clarifications

### Session 2026-09-30 (1ª rodada)

- Q: A regra de bloqueio de spawn deve considerar apenas a área exata ocupada pelo jogador, ou também uma proximidade adicional? → A: Não há regra de proximidade. Todos os veículos são criados **fora da área visível**, acima do topo da tela.
- Q: A decoração deve ocupar uma única faixa de profundidade ao lado da estrada, ou admitir múltiplas profundidades? → A: **Múltiplas profundidades** por lado, para dar mais profundidade visual.
- Q: Qual o comportamento da decoração durante a transição de redução de 4 para 2 vias? → A: **Reposicionamento contínuo** dos elementos afetados para fora da nova área trafegável, mantendo a margem de segurança, sem ocultá-los de forma abrupta.
- Q: Como a decoração deve ser criada e descartada ao longo do jogo? → A: Respeitando a "rolagem" durante a aceleração: os elementos são criados **fora da área do jogo, no topo da tela**, tendem para a parte inferior conforme o carro avança e são **limpos ao alcançar o final da tela**, dando lugar a novas decorações, para controlar o consumo de memória.

### Session 2026-09-30 (2ª rodada — validação do comportamento de movimentação)

- Q: Como os veículos de trânsito devem se movimentar em relação à tela quando o jogador deixa de acelerar? → A: Os veículos **mantêm o próprio deslocamento normal** e **sobem em direção ao topo da tela**, tornando-se invisíveis para o jogador. Isso **corrige** a afirmação da 1ª rodada de que os veículos nunca subiriam na tela: como a velocidade *atual* do jogador pode ficar abaixo da velocidade de um veículo já em cena, o movimento relativo pode ser ascendente.
- Q: Quando um veículo ultrapassado sai da área do jogo, o que deve acontecer com ele? → A: Deve ser **marcado para remoção** (coleta de lixo), desaparecendo da cena. O mesmo vale para a decoração que se torna completamente invisível, por qualquer borda da tela.
- Q: Onde os veículos devem ser criados, considerando a troca de 2 para 4 vias? → A: Fora da área visível, no topo da tela, **dentro da área da estrada e respeitando a diferença de largura vigente naquele ponto** (a área acima da tela pode corresponder a um trecho de 2 vias enquanto a parte visível corresponde a 4 vias, ou vice-versa).
- Q: O que acontece se o jogador ficar parado? → A: **Nenhuma decoração se move.** Para o trânsito, os veículos visíveis seguem o deslocamento normal e saem pelo topo.
- Q: As decorações podem ser postas sobre a estrada? → A: **Nunca**, nem na área visível, nem no momento da criação acima da área do jogo, nem durante as transições de largura.

### Session 2026-09-30 (3ª rodada — `/speckit.clarify`)

- Q: O que deve acontecer com um veículo de trânsito que está em uma faixa que deixa de existir quando a estrada estreita de 4 para 2 vias? → A: **Mover o veículo para a faixa válida mais próxima**, acompanhando o estreitamento da estrada de forma contínua e preservando seu tipo e sua velocidade. O veículo não aparece nem desaparece da tela por causa da transição.
- Q: Quantos quadros por segundo o jogo deve manter com trânsito e decoração ativos ao mesmo tempo? → A: **60 FPS como meta, com 30 FPS como piso aceitável e sem quedas recorrentes de desempenho.**
- Q: Quando não há mais veículos ou decorações prontos para reutilizar no conjunto de objetos, o que o sistema deve fazer? → A: **Criar um novo objeto apenas naquele instante**, estendendo o conjunto reutilizável sob demanda, em vez de recusar a criação.
- Q: Elementos decorativos podem se sobrepor visualmente uns aos outros, ou o sistema deve mantê-los separados? → A: **Podem se sobrepor na direção lateral**, desde que nenhum ocupe a área trafegável e a margem de segurança seja preservada. O espaçamento mínimo e máximo aplica-se somente à direção de deslocamento.

### Session 2026-10-02 (`/speckit.clarify`)

- Q: Os novos assets de decoração são muito maiores que o mundo do jogo (estrada 144x192 px, veículos 32x64 px), variando de 422x527 a 1072x487 px. Como esses assets devem ser ajustados ao tamanho do mundo sem quebrar a estética de pixel art? → A: **Reescalonar os assets na implementação com filtro de vizinho mais próximo** e exibi-los em **escala 1.0**. A resposta inicial previa redução por fator inteiro, mas a verificação das dimensões reais mostrou que 11 dos 18 assets não são divisíveis por nenhum fator inteiro maior que 1; por isso o requisito passou a ser "sem interpolação, filtro de vizinho mais próximo obrigatório", e não "fator inteiro".

- Q: A pasta `assets/npcs/` tem 18 PNGs que não se encaixam na regra "carros e caminhões" do SPEC-004. Quais desses arquivos devem ser usados como veículos de trânsito? → A: **Todos os arquivos da pasta são usados.** A van foi renomeada para `Carro-prata.png`, o `spritesheet_colecao_12_carros` foi removido por ser redundante com `carro_01` a `carro_12`, e a pasta foi subdividida em quatro subpastas — `caminhao/`, `esporte/`, `passeio/` e `utilitario/` — que se tornam a fonte exclusiva de assets de cada categoria. Permanecem 17 assets.

- Q: A decoração é criada e removida continuamente com o jogador em movimento. Quando o jogador para, o que acontece com os elementos que já estavam em tela nesse momento? → A: **Permanecem na tela congelados** até o jogador voltar a se mover. Nenhum elemento novo é criado e nenhum é removido enquanto o jogador estiver completamente parado.

- Q: A regra nova permite que árvores se repitam até 10 vezes seguidas. Como esse contador de repetição deve ser contado — em toda a tela, separando os lados da estrada, ou separando também as profundidades? → A: **Por lado da estrada.** Cada lado da estrada tem sua própria sequência de até 10 elementos `repeatable` consecutivos (na configuração atual, os assets `arvore`). O limite vale para os elementos de um mesmo lado, somando todas as suas profundidades; os dois lados contam de forma independente.

### Session 2026-10-05 (ajustes pós-implementação — validados nos testes manuais da SPEC-005)

- Q: Os veículos eram apresentados em lote: 5 juntos, depois seca de alguns segundos após o jogador ultrapassar o último. Qual é a densidade exigida? → A: Manter **ao menos 3 veículos na estrada junto ao jogador** (na tela ou entrando logo acima dela), com reposição imediata — um nascimento por quadro, logo acima da tela — quando abaixo do mínimo, formando uma esteira contínua em vez de lotes. O valor é configurável e pode subir com a dificuldade. Registrado em FR-063 e SC-028.
- Q: Qual é o máximo de NPCs visíveis na estrada? → A: **No máximo 5 visíveis** no nível mais difícil (Gelo); o teto é um mapa por nível de dificuldade em configuração, aplicado aos veículos ativos (visíveis mais os a caminho), e fica acessível ao SPEC-008. Registrado em FR-064 e SC-028.
- Q: Vários veículos nasciam sobrepostos ou colados uns aos outros. Qual a separação exigida no nascimento? → A: **Separação retangular mínima configurável** (`traffic_min_separation`): folga lateral **ou** longitudinal acima do valor. O espaçamento longitudinal completo segue exigido no fluxo normal; no enchimento abaixo do mínimo (reposição rápida e invisível) vale a separação retangular. Registrado na redação atualizada de FR-019 e no caso de borda "Espaço longitudinal insuficiente".
- Q: Veículos mais rápidos em outra faixa pareciam travados na velocidade de um mais lento (a diferença de velocidade entre categorias "apagava" em algumas situações). → A: O agrupamento em comboio considera **apenas o líder do mesmo corredor lateral**, definido como a interseção das projeções laterais dos dois veículos (folga lateral negativa); veículos em corredores distintos mantêm a velocidade própria da categoria, conforme FR-007 e FR-011. Registrado em SC-029 e SC-006.
- Q: Um caminhão saía da tela preso na velocidade de um esporte com o jogador no máximo, como se todas as categorias tivessem a mesma velocidade. Como corrigir sem mexer nas velocidades? → A: Três medidas juntas, derivadas de configuração: (1) **faixas laterais reservadas por velocidade** (mais rápido à esquerda, mais lento à direita) — velocidades diferentes nunca compartilham corredor, tornando o comboio estruturalmente impossível sem starving de categorias lentas; (2) corredor lateral passa a ser a **interseção das projeções laterais** no líder e no limitador (antes, folgas laterais de até a separação mínima acoplavam faixas vizinhas); (3) o espaçamento longitudinal mínimo do limitador passa a ser **no mínimo a soma das meias-alturas + separação retangular** (antes, 70 px fixos deixavam o caminhão de 128 px grudado no carro da frente). Registrado em FR-065, FR-019, SC-030 e no caso de borda "Faixa da velocidade ocupada no nascimento".

---

## Assumptions

- Os SPEC-001, SPEC-002 e SPEC-003 estão concluídos e funcionais. Este SPEC apenas os estende, sem alterar seu comportamento.
- Os assets de decoração fornecidos nas pastas `assets/decoracao/planice/`, `assets/decoracao/deserto/`, `assets/decoracao/floresta/` e `assets/decoracao/gelo/` são utilizados sem recorte e sem seleção de conteúdo. A proporção de cada asset pode ser ajustada, na preparação dos arquivos, para o encaixe na grade de tiles de 32x32 (base de medição do mundo do jogo); fora desse ajuste, a única edição admitida é o **reescalonamento** necessário para colocar cada asset na escala do mundo do jogo, feito com filtro de vizinho mais próximo e identificado durante a implementação (ver FR-046, FR-047 e o caso de borda "Reescalonamento dos assets de decoração").
- Os assets de veículos fornecidos em `assets/npcs/` são utilizados como conjunto inicial, permanecendo configuráveis e substituíveis sem alteração da lógica. A pasta está subdividida em quatro subpastas, uma por categoria: `caminhao/` (1 asset), `esporte/` (3 assets), `passeio/` (6 assets) e `utilitario/` (7 assets), totalizando 17 arquivos PNG. Cada subpasta é a fonte exclusiva dos assets da respectiva categoria.
- A velocidade máxima do veículo do jogador é de **125 km/h**, valor de projeto registrado nesta especificação como referência de comparação. O SPEC-001 define `max_speed=100` em unidades abstratas de física do jogo; essa constante não é alterada por este SPEC, e a conversão entre a unidade abstrata e o km/h de referência fica a cargo do planejamento. A ordem relativa entre as categorias é preservada em qualquer conversão.
- Os elementos decorativos marcados como `repeatable` na configuração estão autorizados a se repetir consecutivamente até 10 vezes por lado da estrada, por composição natural do cenário. A classificação é um dado de configuração e nunca é deduzida do nome do arquivo em tempo de execução (FR-036); nas bibliotecas atuais esse valor é verdadeiro para os 6 assets `arvore`. A regra independe da profundidade.
- Os arquivos `.png` são utilizados como estão; a preservação da estética de pixel art é responsabilidade do projeto e não justifica conversão de formato nesta versão.
- A decoração pertence à camada visual intermediária, distinta do cenário de fundo do SPEC-003. A relação de velocidade entre as camadas é ajustável por configuração.
- A estrada atual é de sentido único, com o jogador sempre percorrendo na mesma direção. Portanto, não há veículos em direção contrária nesta versão.
- A velocidade máxima configurada para qualquer veículo de trânsito deve ser mantida abaixo da velocidade máxima do jogador, em qualquer configuração de dificuldade futura. Isso garante que o jogador ultrapassue todos os veículos ao atingir a velocidade máxima, mas **não** impede que a velocidade atual do jogador fique abaixo da velocidade de um veículo em cena, caso em que o veículo sobe na tela.
- A criação de veículos respeita a geometria da estrada no ponto de criação: um veículo só é criado acima da área visível quando existe faixa livre válida na largura vigente naquele ponto, respeitando o espaçamento mínimo. Por serem criados fora da área visível, nunca há necessidade de uma regra adicional de proximidade ao jogador.
- A remoção de veículos e de elementos decorativos ocorre por qualquer borda da área visível, e somente quando o objeto está completamente fora dela. A remoção é marcada para coleta e nunca consiste em simples ocultação.
- A decoração é distribuída em múltiplas profundidades por lado. A quantidade de profundidades e o espaçamento entre elas são ajustáveis em configuração.
- Durante a transição de redução (4 para 2 vias), os elementos decorativos que se encontram na área que deixa de ser trafegável são reposicionados continuamente para fora da nova área, mantendo a margem de segurança.
- A densidade da decoração é uma configuração visual independente da dificuldade nesta versão; a vinculação entre densidade e dificuldade fica a cargo do SPEC-008.
- O jogo não inclui áudio nesta fase; nenhum requisito de áudio é definido para o trânsito ou a decoração.
- O posicionamento da decoração deve considerar as dimensões reais de cada asset, pois não há garantia de tamanho uniforme entre os arquivos.
- Elementos decorativos podem se sobrepor visualmente na direção lateral, como ocorre naturalmente em cenários de pixel art. Essa sobreposição é diferente da sobreposição ao longo da direção de deslocamento, que permanece sujeita ao espaçamento longitudinal mínimo.
- O desempenho visual é limitado por renderização e lógica; adicionar veículos de trânsito e decoração não pode introduzir regressão perceptível de taxa de quadros. A meta de 60 FPS, com 30 FPS como piso, vale para o jogo completo em movimento normal.

---

## Fora de Escopo

Os itens a seguir estão explicitamente fora do escopo desta especificação e não devem ser implementados:

- Colisões entre jogador e trânsito, jogador e decoração, trânsito e decoração, ou entre decorações.
- Dano, perda de velocidade por colisão e efeitos de impacto.
- Drift e derrapagem.
- Combustível e consumo de combustível.
- Fim de jogo e vitória.
- Distância percorrida e checkpoints.
- Dificuldade dinâmica e desbloqueio de níveis.
- Obstáculos decorativos.
- Trânsito em sentido contrário, enquanto a estrada for de sentido único.
- Mudança automática de ambiente.
- Efeitos climáticos: chuva, neve e tempestade de areia.
- Ciclo dia/noite.
- Inteligência artificial avançada dos veículos, ultrapassagem inteligente e comportamento estratégico.
- Pontuação.

- **Reescalonamento dos assets de decoração**: os assets são fornecidos em resolução maior que a do mundo do jogo e **11 dos 18 originais não são divisíveis por nenhum fator inteiro maior que 1**, o que torna impossível reduzi-los preservando a grade de pixels por divisão exata. A preparação dos arquivos coloca cada asset na base de tiles de 32x32 com filtro de vizinho mais próximo, resultando em alturas entre 3% e 35% da área visível, e o asset passa a ser exibido em escala 1.0. Nenhum asset é exibido por escala fracionária sobre o arquivo original.

---

## Preparação para as Próximas Especificações

### SPEC-005 — Colisão e Drift

Esta especificação deixa os veículos de trânsito identificáveis e com posição e área ocupada conhecidas, de modo que o sistema de colisões possa consumi-los como entrada, sem que nenhuma lógica de colisão, dano, perda de velocidade ou drift seja antecipada aqui.

### SPEC-008 — Sistema de Dificuldade

Esta especificação disponibiliza externamente os parâmetros de trânsito e de decoração que a dificuldade poderá controlar (densidade, velocidade, frequência por categoria de veículo, quantidade máxima de veículos, intervalo de spawn, densidade e escala da decoração), sem definir valores por nível e sem implementar qualquer progressão de dificuldade.
