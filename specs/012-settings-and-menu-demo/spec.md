# Feature Specification: Menu de Configurações Aprimorado e Menu Principal Dinâmico

**Feature Branch**: `012-settings-and-menu-demo`

**Created**: 2026-10-18

**Status**: Draft

**Input**: User description *(resumo fiel e completa do documento integral "SPEC-012 — Melhorias no Menu de Configurações e Menu Principal Dinâmico" fornecido na mensagem de ativação do comando; os RF-001 a RF-011 e as seções 4 a 7 abaixo reproduzem seu conteúdo normativo)*: "# SPEC-012 — Melhorias no Menu de Configurações e Menu Principal Dinâmico

## 1. Objetivo

Melhorar a experiência inicial do jogador por meio de ajustes no menu de configurações e da introdução de uma demonstração automática de gameplay no menu principal.

A implementação deverá preservar a estrutura visual e funcional dos menus existentes, acrescentando:

- Controle geral de áudio ligado/desligado.
- Seleção de resolução da janela.
- Aplicação imediata das configurações.
- Persistência das preferências entre sessões.
- Demonstração visual automática de corrida no menu principal.
- Exibição cíclica dos quatro ambientes do jogo.
- Trânsito reduzido de veículos NPC.
- Transições suaves (*fade*) entre os ambientes.
- Gerenciamento adequado do ciclo de vida da demonstração.

A implementação deverá reutilizar os sistemas e recursos existentes, evitando duplicar funcionalidades já disponíveis.

## 2. Contexto do projeto

O jogo possui os seguintes componentes relevantes: gerenciador de estado geral do jogo, veículo do jogador, controlador de movimentação dos veículos, gerenciador de trânsito, veículos NPC, estrada, gerenciador de progressão da pista e ambientes, gerenciador de interface e gerenciador centralizado de áudio.

Os estados de jogo existentes incluem: MENU, READY, PLAYING, PAUSED, VICTORY e GAME_OVER.

Os quatro ambientes existentes são: Planície, Deserto, Floresta e Gelo.

O sistema de áudio básico já foi implementado na SPEC-010. O sistema de dificuldade e os modos Relaxante, Normal e Desafio já foram implementados na SPEC-009. A SPEC-012 não deverá modificar esses sistemas além do necessário para integrar as funcionalidades descritas neste documento.

## 3. Escopo funcional

A especificação está dividida em dois grupos: melhorias no menu de configurações (Parte A) e demonstração automática no menu principal (Parte B).

### PARTE A — MELHORIAS NO MENU DE CONFIGURAÇÕES

**RF-001 — Controle geral de áudio**: opção no menu de configurações para ativar/desativar todos os áudios do jogo, atuando centralizadamente sobre todos os sons gerenciados pelo sistema de áudio, aplicada imediatamente, persistida entre sessões, carregada na inicialização com padrão ativado quando não houver preferência salva. Ao desativar, nenhum efeito sonoro permanece audível; ao reativar, os sons voltam a funcionar normalmente, incluindo colisão, caminhão e carro existentes, e o menu continua funcionando normalmente com áudio desativado. A desativação deve alcançar também sons adicionados futuramente ao sistema centralizado.

**RF-002 — Seleção de resolução da janela**: opção no menu de configurações para escolher entre 640 × 480 e 1024 × 768 (ambas 4:3), aplicada imediatamente, mantida durante a sessão, persistida e restaurada na inicialização, com resolução padrão do projeto na ausência de preferência. A alteração não reinicia a partida nem modifica indevidamente o estado do jogo, preserva a proporção visual dos elementos da interface e não pode provocar elementos fora dos limites da tela, botões inacessíveis, sobreposição indevida, cortes no título ou nas opções, distorção dos sprites ou posicionamento incorreto dos elementos de gameplay. Menu e demonstração devem funcionar nas duas resoluções.

**RF-003 — Persistência das configurações**: armazenamento do estado geral do áudio (ativado/desativado) e da resolução selecionada em um arquivo próprio de preferências, separado do arquivo de progresso do jogador; carregamento na inicialização; gravação quando o jogador altera as opções; validação dos valores salvos antes de aplicá-los; uso de valores padrão se o arquivo não existir; recuperação segura diante de dados inválidos; ausência do arquivo nunca impede o jogo de iniciar. Reutilizar mecanismo de persistência já existente se houver um apropriado — nunca criar uma segunda solução paralela.

### PARTE B — MENU PRINCIPAL DINÂMICO

**RF-004 — Demonstração automática de gameplay**: o menu principal deixa de usar exclusivamente fundo estático e passa a apresentar demonstração automática, exclusivamente visual, que começa ao abrir o menu: estrada de duas vias ocupando a área de cenário, um dos quatro ambientes, alguns veículos NPC trafegando, movimento que cria a impressão de corrida em andamento, transição para o próximo ambiente após intervalo configurado, ciclo contando enquanto o menu estiver ativo. O jogador não controla veículo na demonstração; título e opções permanecem em primeiro plano. A demonstração é independente de corrida real: não inicia partida nem altera estado persistente, e não é necessário rodar uma corrida real em segundo plano.

**RF-005 — Ciclo de ambientes**: ordem Planície → Deserto → Floresta → Gelo → Planície, cada ambiente por intervalo configurável (inicial recomendado de 8 a 12 segundos), percorrido continuamente enquanto o menu estiver ativo, com mudança feita por transição suave controlada pelo sistema de demonstração e sem que dois ambientes fiquem visíveis simultaneamente de maneira indesejada.

**RF-006 — Transição suave entre ambientes**: a demonstração atual segue até o início da transição; imagem escurece gradualmente; no ponto de transição o cenário é trocado; imagem clareia gradualmente revelando o novo cenário; o trânsito continua normalmente depois. Parâmetros configuráveis: duração do escurecimento, duração do clareamento e intervalo de exibição de cada ambiente (inicial de 0,5 a 1 segundo por etapa de *fade*). A transição não bloqueia a interface nem impede selecionar as opções, e a animação deve poder ser interrompida ou cancelada com segurança quando a demonstração encerrar, sem deixar a tela escurecida.

**RF-007 — Trânsito reduzido de NPCs**: dois a quatro NPCs visíveis simultaneamente (referência inicial ajustável), usando os sprites e tipos de veículos existentes, movendo-se de cima para baixo, distribuídos sem sobreposições excessivas, dentro dos limites visuais da estrada, sem exigir interação do jogador, removidos ou reutilizados ao saírem da área visível, com quantidade controlada. Velocidade visual fixa e controlada, independente do modo de dificuldade. Colisões reais não são necessárias: nada de perdas de combustível, penalidades de pontuação, alterações de recordes ou troféus, nem efeitos de colisão que interfiram na interface do menu.

**RF-008 — Controlador da demonstração**: mecanismo de controle próprio (novo componente ou extensão de existente, conforme a arquitetura atual) responsável por iniciar a demonstração ao exibir o menu, selecionar o ambiente, controlar durações, gerenciar transições, controlar movimentação e quantidade de NPCs, encerrar/pausar quando necessário, liberar recursos, e reiniciar o ciclo de maneira consistente ao voltar ao menu. Deve reutilizar componentes visuais existentes (estrada, cenários, sprites, decoração, mecanismos de movimentação) sem inicializar desnecessariamente sistemas de gameplay, sem recriar uma segunda versão completa de estrada ou trânsito. Isolamento: opera separadamente de controle do jogador, combustível, pontuação, recordes, troféus, vitória, derrota e progressão real, impedindo que eventos visuais da demonstração sejam interpretados como eventos reais.

**RF-009 — Integração com a navegação do menu**: ao abrir o menu, a demonstração inicia automaticamente com ambiente inicial Planície e interface acessível; ao iniciar corrida, a demonstração encerra ou pausa imediatamente (sem NPCs em segundo plano, sem *fade* pendente, sem interferir na inicialização da corrida); ao retornar ao menu, a demonstração reinicia com recursos reutilizados de forma consistente (sem tela escura, sem acúmulo de NPCs, ciclo funcionando); se existirem outras telas acessíveis a partir do menu, a demonstração é interrompida/pausada quando o menu deixa de estar visível e retoma quando ele volta.

**RF-010 — Interface e compatibilidade visual**: nome do jogo visível, opções acessíveis, fundo animado sem cobrir elementos interativos, identidade visual pixel art preservada, proporções corretas, funcionamento nas resoluções 640 × 480 e 1024 × 768, *fade* cobrindo a área de demonstração sem prejudicar permanentemente a interface; se necessário, fundo semitransparente ou sombra atrás dos textos para legibilidade.

**RF-011 — Desempenho e gerenciamento de recursos**: quantidade de NPCs limitada; objetos fora da área removidos ou reutilizados; criação/destruição excessiva evitada; recursos visuais comuns reutilizados; demonstração interrompida quando o menu deixa de estar ativo; nenhum animação ou processo desnecessário persistindo após o encerramento; sem vazamentos de recursos ou referências inválidas; desempenho verificado nas duas resoluções suportadas.

## 4. Requisitos técnicos e de arquitetura

**4.1 Inspeção inicial obrigatória**: antes de implementar, inspecionar a estrutura atual dos menus, o fluxo de navegação entre menu e gameplay, o gerenciador de estado do jogo, o gerenciador de interface, a integração do sistema de áudio, o mecanismo de persistência disponível, a configuração de janela, escala de exibição e dimensionamento da interface, a estrutura dos ambientes, a estrada, os NPCs, os mecanismos existentes de geração e remoção de objetos e a versão do motor utilizada. A implementação parte do estado real do repositório, sem presumir nomes de cenas, arquivos, componentes ou diretórios ainda não verificados.

**4.2 Reutilização da arquitetura**: reutilizar sistemas existentes quando não houver acoplamento indevido. O menu principal mantém sua estrutura atual, recebendo a demonstração como componente de fundo. O menu de configurações é ampliado, não substituído por um menu paralelo.

**4.3 Separação entre demonstração e gameplay**: ciclo de vida independente da corrida real; não iniciar combustível, pontuação ou condições de vitória/derrota apenas para produzir movimento visual; comportamentos não necessários de componentes reutilizados permanecem desativados durante a demonstração.

**4.4 Configuração centralizada**: resolução padrão, estado padrão do áudio, duração de exibição de cada ambiente, duração do escurecimento, duração do clareamento, quantidade máxima de NPCs simultâneos, intervalo de aparecimento dos NPCs e velocidade visual da demonstração devem ser configuráveis e não podem ficar espalhados pelo código como números mágicos.

**4.5 Compatibilidade com a versão do motor**: utilizar apenas recursos compatíveis com a versão do motor já instalada no projeto; não atualizar o motor como parte desta especificação.

## 5. Restrições

A implementação não deverá: criar um menu principal paralelo; substituir desnecessariamente a estrutura atual do menu; iniciar uma corrida real em segundo plano; exibir o veículo controlado pelo jogador na demonstração; modificar combustível, pontuação, troféus ou recordes durante a demonstração; alterar os multiplicadores de dificuldade da SPEC-009; introduzir novos sons no menu; criar sistemas de persistência duplicados; recriar os sistemas de estrada ou trânsito sem necessidade; permitir que a demonstração continue executando desnecessariamente durante uma corrida; deixar NPCs ou animações acumularem-se após retornar ao menu; permitir que uma transição interrompida deixe a tela escurecida; comprometer a legibilidade da interface; introduzir modos de tela cheia, controles remapeáveis ou volume independente por categoria. A demonstração permanece silenciosa, mantendo o comportamento estabelecido para o menu atual.

## 6. Estratégia de testes

- **Teste A — Controle geral de áudio**: ligar/desligar áudio nas configurações, verificar todos os sons existentes, navegar no menu, iniciar corrida, confirmar silêncio total, reativar e confirmar retorno dos sons, reiniciar o jogo e conferir a preferência salva.
- **Teste B — Resolução**: alternar entre 1024 × 768 e 640 × 480, verificar menu e configurações em cada uma, iniciar corrida em cada resolução, reiniciar o jogo e conferir a resolução salva.
- **Teste C — Persistência**: alterar áudio e resolução, encerrar, reiniciar, conferir preferências aplicadas e testar inicialização sem arquivo de configuração.
- **Teste D — Sequência de ambientes**: abrir o menu e confirmar Planície → Deserto → Floresta → Gelo → Planície.
- **Teste E — Transições suaves**: observar cada transição nas duas resoluções e iniciar uma corrida durante uma transição, conferindo encerramento seguro.
- **Teste F — Trânsito da demonstração**: contar NPCs, observar movimento e limites da estrada, aguardar saída da tela e reciclagem, aguardar vários ciclos de ambientes.
- **Teste G — Isolamento do gameplay**: deixar a demonstração rodar por vários ciclos, iniciar corrida e verificar combustível inicial, pontuação, troféus e recordes, concluir/abandonar e retornar ao menu, repetindo o processo.
- **Teste H — Ciclo de vida**: alternar várias vezes entre menu, configurações e corrida, conferindo início/parada consistente da demonstração sem acúmulo de NPCs, animações ou processos.
- **Teste I — Desempenho**: executar a demonstração por vários minutos, alternar repetidamente entre menu e gameplay, testar as duas resoluções, observar fluidez e erros no console.

**Resultado esperado de cada teste**: conforme os critérios de aceitação dos RF-001 a RF-011 e os critérios de sucesso desta especificação.

**Testes automatizados obrigatórios** (além da validação manual A–I): cobrir a lógica determinística da feature — ordem e retorno do ciclo dos quatro ambientes; carregamento, validação e recuperação das preferências (arquivo ausente ou inválido); e limite de quantidade, posicionamento e reciclagem/reutilização dos NPCs da demonstração.

## 7. Definição de concluído

A SPEC-012 será considerada concluída quando: o controle geral de áudio estiver funcional; as duas resoluções estiverem disponíveis e funcionando; as preferências forem persistidas corretamente; a demonstração automática estiver integrada ao menu principal; os quatro ambientes forem apresentados na sequência definida; as transições suaves estiverem implementadas; o trânsito reduzido de NPCs estiver funcional; a demonstração estiver isolada do gameplay real; a demonstração for interrompida e retomada corretamente conforme a navegação; a interface continuar legível nas duas resoluções; o gerenciamento de recursos estiver funcionando sem acúmulos; os testes definidos forem executados; não houver regressões nos sistemas existentes.

Ao finalizar, apresentar um resumo dos arquivos criados ou alterados, das funcionalidades implementadas, dos testes realizados e de eventuais limitações encontradas. Qualquer requisito não concluído deverá ser identificado explicitamente, com sua justificativa e os próximos passos necessários."

## Clarifications

### Session 2026-10-18

- Q: As preferências de áudio e resolução devem ser gravadas em um arquivo de preferências próprio ou no mesmo arquivo de progresso/jogador que já existe no projeto? → A: **Arquivo próprio de preferências**, separado do arquivo de progresso, reutilizando o mesmo mecanismo e formato de gravação já existentes — sem duplicar a solução de persistência.
- Q: Ao escolher 640 × 480 ou 1024 × 768, a janela do jogo deve ficar com esse tamanho fixo ou o jogador também pode redimensioná-la livremente pelas bordas? → A: **Tamanho fixo** — a janela só muda ao selecionar uma das duas resoluções, sem redimensionamento livre pelo jogador.
- Q: A seção de testes da spec deve exigir também testes automatizados (além dos Testes A–I manuais) para a lógica determinística da demonstração e das preferências? → A: **Sim** — testes automatizados para o ciclo/ordem dos quatro ambientes, carregamento/validação/recuperação de preferências e limite/reciclagem de NPCs da demonstração, além dos Testes A–I manuais.
- Q: O menu de configurações (áudio e resolução) deve ficar acessível apenas a partir do menu principal, ou também a partir do menu de pausa durante uma corrida? → A: **Apenas a partir do menu principal** (escopo do documento-fonte); o menu de pausa não ganha acesso às configurações.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Desligar e religar todo o áudio pelas configurações (Priority: P1)

O jogador abre o menu de configurações e encontra uma opção de áudio ligado/desligado. Ao desativar, nenhum som do jogo fica audível (inclusive durante uma corrida); ao reativar, os sons voltam a funcionar normalmente. A escolha é aplicada na hora e continua valendo quando o jogo é fechado e aberto de novo.

**Why this priority**: é a mudança mais simples e autônoma da Parte A, traz valor imediato ao jogador (conforto/controle) e valida o mecanismo de preferências que as demais configurações vão reutilizar.

**Independent Test**: pode ser testada apenas abrindo as configurações, alternando a opção de áudio, verificando o silêncio/restauração dos sons existentes e reiniciando o jogo para conferir a preferência persistida.

**Acceptance Scenarios**:

1. **Given** o jogo iniciado com áudio ativado, **When** o jogador desativa o áudio nas configurações, **Then** nenhum efeito sonoro permanece audível e a opção reflete o novo estado.
2. **Given** o áudio desativado, **When** o jogador reativa a opção, **Then** os sons de colisão, caminhão e carro voltam a funcionar sem reiniciar o jogo.
3. **Given** uma preferência de áudio salva, **When** o jogo é reiniciado, **Then** a preferência é carregada e aplicada automaticamente.
4. **Given** o áudio desativado, **When** o jogador navega pelo menu e inicia uma corrida, **Then** a interface continua plenamente funcional.

---

### User Story 2 — Escolher a resolução da janela nas configurações (Priority: P2)

O jogador abre as configurações e escolhe entre 640 × 480 e 1024 × 768. A janela muda imediatamente, a interface continua legível e íntegra (sem cortes, sobreposições ou botões inacessíveis), os sprites mantêm as proporções, e a escolha é salva para as próximas sessões.

**Why this priority**: depende do mesmo mecanismo de persistência da US1, tem impacto visual direto na experiência, mas é menos crítica do que o áudio (ausência de suporte ainda deixa o jogo plenamente jogável).

**Independent Test**: pode ser testada apenas alternando entre as duas resoluções nas configurações, conferindo o menu e uma corrida em cada resolução e reiniciando o jogo para verificar a preferência salva.

**Acceptance Scenarios**:

1. **Given** o menu de configurações aberto, **When** o jogador seleciona 1024 × 768, **Then** a resolução é aplicada imediatamente e todas as opções continuam acessíveis e legíveis.
2. **Given** o jogo em 1024 × 768, **When** o jogador seleciona 640 × 480, **Then** a interface não apresenta cortes, sobreposições nem distorção dos sprites.
3. **Given** uma resolução salva, **When** o jogo é reiniciado, **Then** a resolução é aplicada automaticamente na inicialização.
4. **Given** o menu principal aberto após uma corrida anterior, **When** o jogador altera a resolução pelas configurações, **Then** nada é reiniciado e o estado do jogo (inclusive o progresso salvo) permanece intacto.

---

### User Story 3 — Ver a demonstração de corrida com os quatro ambientes no menu principal (Priority: P3)

Ao abrir o menu principal, o jogador vê o fundo ganhar vida: uma estrada de dois caminhos com veículos trafegando, ambiente que muda a cada poucos segundos na ordem Planície → Deserto → Floresta → Gelo → Planície, com transição suave de escurecimento e clareamento entre eles. Título e opções continuam legíveis em primeiro plano e o menu segue totalmente navegável.

**Why this priority**: é o ganho de apresentação central da especificação, mas depende da integração correta com a navegação existente e é menos crítica do que as configurações básicas de preferências.

**Independent Test**: pode ser testada apenas abrindo o menu principal, observando o movimento, conferindo a ordem dos ambientes e as transições, e selecionando uma opção do menu durante o efeito.

**Acceptance Scenarios**:

1. **Given** o menu principal exibido, **When** a demonstração começa, **Then** uma estrada de duas vias ocupa a área de cenário com veículos em movimento e sem veículo do jogador.
2. **Given** a demonstração em Planície, **When** o intervalo configurado termina, **Then** ocorre uma transição suave para Deserto e depois Floresta, Gelo e novamente Planície.
3. **Given** uma transição em andamento, **When** o jogador seleciona uma opção do menu, **Then** a interface responde normalmente e nada fica permanentemente escuro.
4. **Given** o menu principal ativo, **When** a demonstração roda por vários ciclos, **Then** título e opções permanecem visíveis e legíveis em todos os ambientes.

---

### User Story 4 — Demonstração isolada do gameplay e com ciclo de vida alinhado à navegação (Priority: P4)

A demonstração mostra de dois a quatro veículos NPC em velocidade visual constante, independentemente do modo de dificuldade, sem produzir nenhum efeito de corrida real. Ela inicia ao abrir o menu, para ao iniciar uma corrida ou sair do menu, e reinicia limpa ao voltar — sem veículos acumulados, animações presas ou processos sobrando.

**Why this priority**: garante que a demonstração seja segura e sustentável; é validada após a demonstração existir (US3), mas é indispensável para a conclusão da feature.

**Independent Test**: pode ser testada alternando repetidamente entre menu, configurações e corrida, conferindo contagem de veículos, ausência de efeitos em combustível/pontuação/recordes/troféus e ausência de resíduos após cada retorno ao menu.

**Acceptance Scenarios**:

1. **Given** a demonstração ativa, **When** o jogador inicia uma corrida, **Then** a demonstração encerra imediatamente (sem NPCs em segundo plano e sem *fade* pendente).
2. **Given** vários retornos ao menu principal, **When** a demonstração reinicia, **Then** a contagem de veículos volta ao nível inicial, sem acúmulo, e o cenário não inicia escuro.
3. **Given** a demonstração em qualquer ambiente e modo de dificuldade, **When** se observa a velocidade dos NPCs, **Then** ela é a mesma, sem variação por modo.
4. **Given** a demonstração rodando por vários minutos, **When** se verifica o estado persistente do jogador, **Then** combustível, pontuação, recordes e troféus permanecem inalterados.

---

### Edge Cases

- Arquivo de preferências inexistente (primeira execução): o jogo inicia com os valores padrão e nunca falha ao abrir.
- Arquivo de preferências corrompido ou com valores fora do conjunto válido (resolução desconhecida, áudio em formato inválido): o sistema descarta os dados inválidos, aplica os padrões e segue funcionando; a próxima alteração regrava um arquivo válido.
- Início de corrida no exato momento de uma transição de ambiente: a transição é cancelada com segurança e nenhuma tela permanece escura.
- Retorno ao menu logo após sair dele (idas e vindas rápidas): nenhum acúmulo de veículos, animações ou processos.
- Troca de resolução durante uma transição da demonstração: a demonstração e a transição continuam corretas na nova resolução, sem corte indevido nem tela escura.
- Alternar a opção de áudio repetidamente em sequência: cada alternância reflete imediatamente o estado final, sem sons "presos" tocando.
- Menu de configurações acessado a partir do menu principal: a demonstração é pausada/interrompida enquanto o menu principal não está visível e retoma ao voltar.
- Permanência prolongada no menu (vários minutos): a sequência de ambientes continua ciclando sem erro nem crescimento descontrolado de objetos.

## Requirements *(mandatory)*

### Functional Requirements

**Configurações (Parte A)**

- **FR-001**: O menu de configurações, acessível a partir do menu principal (e não a partir do menu de pausa), MUST oferecer uma opção de áudio ligado/desligado, visível e operável pelo jogador.
- **FR-002**: O controle de áudio MUST atuar de forma centralizada sobre todos os sons do jogo, com efeito imediato sem reiniciar o jogo, alcançando também sons adicionados futuramente ao sistema centralizado.
- **FR-003**: Com o áudio desativado, nenhum efeito sonoro MUST permanecer audível; com o áudio reativado, os sons existentes MUST voltar a funcionar normalmente, e o menu MUST continuar funcionando com o áudio desativado.
- **FR-004**: O menu de configurações MUST oferecer a seleção de resolução entre 640 × 480 e 1024 × 768, ambas em proporção 4:3.
- **FR-005**: A troca de resolução MUST ser aplicada imediatamente, MUST manter a resolução ativa durante a sessão e MUST NOT reiniciar o jogo nem alterar indevidamente o estado do jogo (inclusive o progresso salvo). A janela MUST manter tamanho fixo: só altera ao selecionar uma das duas resoluções, sem redimensionamento livre pelo jogador.
- **FR-006**: Nas duas resoluções, a interface MUST permanecer legível e acessível e MUST NOT apresentar elementos fora dos limites, botões inacessíveis, sobreposições indevidas, cortes no título/opções, distorção de sprites ou posicionamento incorreto dos elementos de gameplay; menu e demonstração MUST funcionar em ambas.
- **FR-007**: As preferências de áudio e resolução MUST ser carregadas na inicialização e MUST ser persistidas sempre que o jogador alterar as opções, estando disponíveis nas sessões seguintes.
- **FR-008**: Os valores salvos MUST ser validados antes de aplicados; dados inválidos MUST resultar em recuperação segura com valores padrão, e a ausência do arquivo MUST NOT impedir o jogo de iniciar.
- **FR-009**: Na ausência de preferência salva, o jogo MUST usar valores padrão definidos pela implementação, com áudio ativado e a resolução padrão do projeto.
- **FR-010**: As preferências MUST ser gravadas em um arquivo próprio de preferências, separado do arquivo de progresso do jogador, reutilizando o mesmo mecanismo de persistência já existente; MUST NOT ser criada uma segunda solução paralela de persistência nem misturar preferências com dados de progresso.

**Demonstração no menu principal (Parte B)**

- **FR-011**: Ao exibir o menu principal, a demonstração MUST iniciar automaticamente e MUST continuar enquanto o menu principal estiver ativo.
- **FR-012**: A demonstração MUST mostrar uma estrada de dois caminhos ocupando a área de cenário, com movimento que crie a impressão de corrida em andamento, e MUST NOT exibir nem exigir um veículo controlado pelo jogador.
- **FR-013**: A demonstração MUST ser independente de corrida real: MUST NOT iniciar uma partida, MUST NOT alterar dados persistentes do jogador e MUST NOT exigir execução de gameplay em segundo plano.
- **FR-014**: A demonstração MUST percorrer os quatro ambientes na ordem Planície → Deserto → Floresta → Gelo → Planície, de forma contínua, com duração de cada ambiente configurável (intervalo inicial de aproximadamente 8 a 12 segundos) e ambiente inicial Planície.
- **FR-015**: Cada mudança de ambiente MUST usar transição suave de escurecimento seguida de clareamento, com durações configuráveis (inicial de aproximadamente 0,5 a 1 segundo por etapa), MUST NOT deixar dois ambientes visíveis simultaneamente de maneira indesejada, MUST NOT bloquear a interface e MUST poder ser interrompida com segurança sem deixar a tela escurecida.
- **FR-016**: A demonstração MUST exibir de dois a quatro veículos NPC simultaneamente (quantidade máxima configurável), usando os sprites e tipos de veículos existentes, movendo-se de cima para baixo, distribuídos sem sobreposições excessivas, dentro dos limites visuais da estrada, e MUST reutilizar ou remover os veículos que saírem da área visível.
- **FR-017**: A velocidade visual da demonstração MUST ser fixa e configurável, e MUST ser independente do modo de dificuldade selecionado.
- **FR-018**: A demonstração MUST NOT produzir efeitos de gameplay persistentes: nada de perdas de combustível, penalidades de pontuação, alterações de recordes ou troféus, nem efeitos de colisão que interfiram na interface do menu.
- **FR-019**: A demonstração MUST ter ciclo de vida definido: iniciar ao exibir o menu, encerrar ou pausar imediatamente ao iniciar uma corrida ou sair do menu, cancelar animações pendentes com segurança e reiniciar de maneira consistente ao retornar ao menu, sem acúmulo de veículos, animações ou processos.
- **FR-020**: A interface do menu MUST permanecer elemento visual prioritário: título e opções MUST permanecer visíveis, legíveis e acessíveis sobre a demonstração, preservando a identidade visual e as proporções nas duas resoluções, com recurso de legibilidade (fundo semitransparente/sombra atrás dos textos) quando necessário.
- **FR-021**: A demonstração MUST ter desempenho controlado: limite de veículos, reutilização/remoção de objetos fora da área, ausência de processos e animações desnecessários após o encerramento, ausência de vazamentos de recursos e desempenho verificado nas duas resoluções.
- **FR-022**: Os parâmetros da feature MUST ser configuráveis de forma centralizada: resolução padrão, estado padrão do áudio, duração de exibição de cada ambiente, duração do escurecimento, duração do clareamento, quantidade máxima de NPCs simultâneos, intervalo de aparecimento dos NPCs e velocidade visual da demonstração — sem números mágicos espalhados pelo código.

### Key Entities

- **Preferências do Jogador**: estado geral do áudio (ativado/desativado) e resolução selecionada (640 × 480 ou 1024 × 768); persistem entre sessões em um arquivo próprio de preferências (separado do progresso do jogador), têm valores padrão e são validadas a cada carregamento.
- **Demonstração do Menu**: ambiente atual da sequência, tempo restante de exibição, estado da transição (normal/escurecendo/clareando), conjunto de veículos NPCs ativos e situação geral (em execução/pausada/encerrada); vive apenas enquanto o menu principal estiver visível.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ao alternar a opção de áudio, a mudança é percebida imediatamente (em até 1 segundo), sem reiniciar o jogo, em 100% das alternâncias testadas.
- **SC-002**: Após reiniciar o jogo, áudio e resolução salvos são restaurados corretamente em 100% das tentativas (mínimo de 5 reinícios consecutivos por teste).
- **SC-003**: Com o arquivo de preferências ausente ou inválido, o jogo inicia normalmente com valores padrão em 100% dos casos testados.
- **SC-004**: A cada abertura do menu, a sequência completa Planície → Deserto → Floresta → Gelo → Planície é observada em ordem, em 100% das observações, em no máximo 60 segundos por ciclo completo.
- **SC-005**: Cada transição de ambiente dura no máximo 2 segundos no total e não apresenta corte brusco perceptível; após qualquer interrupção, a tela retorna ao estado normal em até 1 segundo, sem ficar escura.
- **SC-006**: Durante a demonstração, a contagem de veículos NPCs visíveis permanece entre 2 e 4 em 100% das amostragens feitas ao longo de 5 minutos de observação.
- **SC-007**: Após 20 alternâncias consecutivas entre menu e corrida, a contagem de objetos da demonstração retorna ao nível inicial, sem acúmulo (diferença de 0 objetos).
- **SC-008**: Nas duas resoluções, 100% das opções do menu e das configurações permanecem visíveis, legíveis e alcançáveis, sem cortes nem sobreposições.
- **SC-009**: Após ciclos prolongados de demonstração e corridas subsequentes, combustível inicial, pontuação, recordes e troféus apresentam variação zero decorrente da demonstração.
- **SC-010**: A demonstração mantém fluidez perceptivelmente estável por 5 minutos nas duas resoluções, sem erros recorrentes no console e sem crescimento contínuo de objetos ou processos ativos.

## Assumptions

- **Padrões iniciais**: áudio ativado por padrão; resolução padrão = resolução atual do projeto (mantida como está na primeira execução, sem arquivo de preferências); 10 segundos por ambiente; 0,75 s de escurecimento e 0,75 s de clareamento; 3 NPCs simultâneos; 1,5 s entre aparições de NPCs; velocidade visual da demonstração equivalente a uma velocidade de cruzeiro fixa do modo Normal. Todos os valores ficam centralizados e ajustáveis.
- A demonstração ocupa toda a área de fundo do menu principal, ficando atrás do título e das opções (não em um quadro recortado).
- O menu de configurações já existe ou será ampliado no local atual: a especificação exige ampliar a estrutura existente, nunca um menu paralelo; ele é acessível somente a partir do menu principal (não do menu de pausa).
- Preferências são exclusivamente áudio e resolução: tela cheia, volume por categoria e remapeamento de controles estão fora de escopo.
- A janela não é redimensionável livremente: o tamanho de tela é definido exclusivamente pela preferência de resolução (640 × 480 ou 1024 × 768), o que mantém os critérios de legibilidade (SC-008) aplicáveis apenas a esses dois tamanhos.
- A demonstração é silenciosa (sem trilha ou efeitos novos), mantendo o comportamento sonoro atual do menu.
- A numeração/spec label segue a sequência do repositório: este documento é a SPEC-012 (rótulo original do usuário), correspondente ao diretório `specs/012-settings-and-menu-demo`.
