# Feature Specification: Sistema Básico de Áudio

**Feature Branch**: `010-basic-audio-system`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "# SPEC-010 — Sistema Básico de Áudio

## 1. Objetivo

Implementar um sistema básico de áudio para o jogo de corrida 2D Game2D, utilizando três arquivos MP3 para fornecer feedback sonoro durante a corrida.

A implementação deverá ser simples, modular e compatível com a arquitetura existente, permitindo ampliar o sistema de áudio futuramente sem necessidade de reestruturar os componentes atuais.

## 2. Escopo funcional

O sistema utilizará exclusivamente três efeitos sonoros:

| ID      | Áudio           | Finalidade                                                                             |
| ------- | --------------- | -------------------------------------------------------------------------------------- |
| AUD-001 | Som de colisão  | Reproduzir um efeito sonoro quando ocorrer uma colisão envolvendo veículos.            |
| AUD-002 | Som de caminhão | Reproduzir o som do motor dos caminhões NPC durante a corrida.                         |
| AUD-003 | Som de carro    | Reproduzir o som do motor dos carros, incluindo o veículo do jogador e os demais NPCs. |

Os nomes dos arquivos serão definidos conforme os assets disponibilizados pelo usuário. Não será obrigatório renomeá-los.

## 3. Requisitos funcionais

### RF-001 — Som de colisão

* Reproduzir o áudio quando ocorrer uma colisão relevante entre veículos.
* Utilizar o mesmo efeito sonoro para colisões envolvendo o jogador ou NPCs.
* Acionar o som a partir dos eventos do sistema de colisão existente.
* Evitar a reprodução repetitiva e excessiva do mesmo efeito durante uma única colisão.
* Não alterar a física, as consequências ou o comportamento das colisões.

### RF-002 — Som de caminhão

* Reproduzir o áudio correspondente ao motor dos caminhões NPC durante a corrida.
* Permitir reprodução contínua enquanto o caminhão estiver ativo na pista, conforme o comportamento definido para o veículo.
* Interromper a reprodução quando o caminhão deixar de participar do gameplay.
* Evitar que o áudio continue sendo reproduzido por veículos removidos da pista.

### RF-003 — Som de carro

* Utilizar um único arquivo de áudio para o veículo do jogador e todos os NPCs que não sejam caminhões.
* Reproduzir o som enquanto os respectivos veículos estiverem ativos na corrida — para o jogador, **apenas enquanto ele estiver acelerando** (Clarification Q3); para os NPCs, de forma contínua.
* Permitir reprodução contínua do motor durante o gameplay **dos NPCs**; o motor do jogador segue o gate de aceleração (silência ao soltar o pedal, frear ou parar).
* Interromper a reprodução quando o veículo deixar de participar do gameplay.

### RF-004 — Gerenciamento de áudio

* Centralizar o gerenciamento da reprodução em um componente dedicado, preferencialmente o `AudioManager` previsto na arquitetura existente.
* Evitar a criação desnecessária de instâncias de áudio durante cada atualização do jogo.
* Gerenciar corretamente o início, a interrupção e a liberação dos recursos de áudio.
* Permitir que múltiplos veículos produzam sons simultaneamente, respeitando os limites de desempenho.
* Tratar arquivos ausentes ou inválidos sem interromper a execução do jogo.

### RF-005 — Compatibilidade com os modos de jogo

O áudio deverá funcionar nos três modos definidos pela SPEC-009:

| Modo      | Multiplicador de velocidade |
| --------- | --------------------------: |
| Relaxante |                          1× |
| Normal    |                          3× |
| Desafio   |                        4,5× |

*(Valores originais da descrição; para a SPEC-010 prevalece a SPEC-009 vigente: Relaxante 1,0×, Normal 3,0× e Desafio 4,0× — ver Clarifications.)*

O sistema de áudio não deverá modificar as velocidades dos veículos nem aplicar novamente os multiplicadores da dificuldade.

Os sons dos motores deverão permanecer funcionais nos três modos, independentemente da velocidade efetiva dos veículos.

Ajustes dinâmicos de volume ou velocidade de reprodução poderão ser utilizados quando necessários para manter uma experiência sonora adequada, sem introduzir complexidade desnecessária.

### RF-006 — Estados do jogo

* Os sons de gameplay deverão ser reproduzidos somente quando apropriado ao estado atual da corrida.
* Ao pausar o jogo, os sons contínuos dos veículos deverão ser pausados ou interrompidos conforme o comportamento adotado.
* Ao retomar a corrida, os sons deverão voltar a funcionar corretamente.
* Ao entrar em VICTORY ou GAME_OVER, os sons dos veículos deverão ser interrompidos ou encerrados de maneira controlada.
* Não haverá reprodução de áudio no menu principal, no menu de configurações ou durante a navegação pelas interfaces.

## 4. Assets de áudio

Os três arquivos serão armazenados em uma pasta de áudio dentro de `assets`, respeitando a estrutura existente no projeto.

Exemplo de organização:

`assets/audio/`

Os nomes dos arquivos serão definidos conforme os assets efetivamente fornecidos.

**Formato:** MP3.

Não será exigida conversão para OGG. Caso algum arquivo apresente incompatibilidade com a versão da Godot utilizada, a solução deverá ser avaliada antes de alterar o formato dos assets.

Para os sons dos motores, deverá ser verificado se os arquivos permitem reprodução contínua sem interrupções perceptíveis.

## 5. Requisitos técnicos

* Utilizar os recursos de áudio nativos da versão da Godot já instalada no projeto.
* Reaproveitar a arquitetura e os sistemas existentes de veículos, colisões e estados do jogo.
* Evitar dependências externas.
* Não recriar o sistema de colisão ou a lógica de movimentação dos veículos.
* Centralizar as referências aos arquivos de áudio para facilitar futuras alterações.
* Evitar a reprodução duplicada de sons do mesmo veículo.
* Avaliar uma estratégia de gerenciamento de instâncias para impedir que a quantidade de veículos na pista prejudique o desempenho.

A implementação deverá preservar a distinção entre caminhões e demais carros por meio das informações de tipo de veículo já existentes no projeto.

## 6. Critérios de aceitação

A SPEC-010 será considerada concluída quando:

1. Os três arquivos MP3 forem carregados e reproduzidos corretamente.
2. O som de colisão for reproduzido nos eventos relevantes, sem repetições excessivas.
3. Os caminhões NPC utilizarem o som de caminhão.
4. O veículo do jogador e os demais NPCs utilizarem o som de carro.
5. Os sons contínuos forem interrompidos quando os veículos deixarem de participar do gameplay.
6. O áudio funcionar nos modos Relaxante, Normal e Desafio.
7. A pausa e a retomada da corrida gerenciarem corretamente os sons contínuos.
8. Os sons dos veículos não continuarem indevidamente após a vitória ou o Game Over.
9. Nenhum som for reproduzido no menu principal ou nas interfaces de configuração.
10. A ausência de um arquivo de áudio não provocar falhas críticas na execução.
11. O sistema não causar impactos perceptíveis no desempenho ou interferir na lógica do jogo.
12. O som do jogador for reproduzido apenas enquanto ele estiver acelerando e permanecer silencioso quando ele soltar o acelerador, frear ou estiver parado — sem afetar a reprodução contínua dos NPCs (Clarification Q3).

## 7. Fora do escopo

Não fazem parte desta versão:

* Trilha sonora.
* Música no menu.
* Sons de aceleração, frenagem ou drift específicos.
* Alertas sonoros de combustível.
* Sons de coleta de combustível.
* Sons exclusivos para vitória ou Game Over.
* Controle de volume por categoria na interface.
* Sistema avançado de áudio espacial.
* Efeitos sonoros específicos para cada ambiente.

Esses recursos poderão ser incorporados em futuras especificações, conforme a evolução do projeto.

## 8. Orientações para implementação

Antes de implementar, o agente deverá:

1. Inspecionar a estrutura atual do projeto e identificar a versão da Godot utilizada.
2. Localizar os três arquivos MP3 fornecidos.
3. Identificar como os tipos de veículos são representados.
4. Verificar os pontos de integração com os sistemas de colisão e estados do jogo.
5. Implementar o gerenciamento de áudio aproveitando os componentes existentes.
6. Executar testes para verificar reprodução, interrupção, pausa e retomada.

A implementação deverá limitar-se ao escopo desta SPEC, sem introduzir funcionalidades sonoras adicionais.

## 9. Evolução futura

O sistema deverá permitir adicionar novos efeitos sonoros futuramente, como alertas de combustível, coleta de itens, drift, vitória e Game Over.

Essa possibilidade não autoriza a implementação desses recursos nesta etapa."

## Clarifications

### Session 2026-10-16

- Q: O som de colisão deve tocar também quando dois NPCs colidem entre si, ou apenas quando o jogador participa da colisão? → A: Toda colisão veicular relevante toca o mesmo efeito — **jogador×NPC e NPC×NPC**.
- Q: Qual conjunto de multiplicadores de modo deve constar no texto da SPEC-010, se a sua descrição original diz Desafio 4,5× mas a SPEC-009 vigente define 4,0×? → A: Usar a SPEC-009 vigente — **Relaxante 1,0×, Normal 3,0× e Desafio 4,0×**.
- Q: O motor do jogador deve tocar continuamente durante a corrida, como o dos NPCs? → A: Não — **o som do jogador toca apenas enquanto ele estiver acelerando** (entrada de aceleração ativa: `accelerate` pressionado sem `brake`, a mesma condição da fase de aceleração do controle do veículo); ao soltar o acelerador ou frear, **mesmo com o veículo ainda em movimento**, o som do jogador silencia, e com o veículo parado nada toca (subproduto da regra). Os NPCs permanecem com som contínuo inalterado (FR-002/FR-003).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ouvir o impacto das colisões durante a corrida (Priority: P1)

Como jogador, quero ouvir um efeito sonoro sempre que uma colisão entre veículos acontece, para perceber o impacto imediatamente mesmo com a atenção concentrada na pista.

**Why this priority**: a colisão é o evento de maior impacto da corrida (perda de controle, penalidade de combustível) e o feedback sonoro tem valor sozinho — é a fatia mais crítica e entrega um MVP perfeitamente testável.

**Independent Test**: jogar uma corrida, provocar colisões e confirmar o efeito sonoro (e a ausência de repetição excessiva) sem qualquer alteração no comportamento das colisões.

**Acceptance Scenarios**:

1. **Given** uma corrida em andamento, **When** ocorre uma colisão relevante entre veículos (jogador×NPC ou NPC×NPC), **Then** o efeito de colisão é reproduzido.
2. **Given** uma colisão cujo evento se estende ou se repete no mesmo encontro, **When** o evento se resolve, **Then** o efeito não se repete de forma excessiva (uma única reprodução por evento).
3. **Given** uma colisão, **When** o efeito sonoro é reproduzido, **Then** física, consequências e comportamento das colisões permanecem idênticos aos atuais.

---

### User Story 2 - Ouvir os motores dos veículos na pista (Priority: P2)

Como jogador, quero ouvir o motor do meu veículo enquanto acelero, e os motores dos demais carros e dos caminhões enquanto a corrida acontece, distinguindo os tipos de veículo e com os sons parando quando quem toca sai de cena.

**Why this priority**: dá vida à corrida e usa a distinção de tipos de veículo já existente; é independente da US1, mas menos crítica do que o feedback de colisão.

**Independent Test**: iniciar uma corrida e confirmar que o jogador e os NPCs não-caminhão usam o som de carro, os caminhões usam o som de caminhão, tudo soa simultaneamente com fluidez, e que os sons são interrompidos quando o veículo deixa o gameplay.

**Acceptance Scenarios**:

1. **Given** uma corrida em andamento com caminhões na pista, **When** esses veículos estão ativos, **Then** eles reproduzem o som de caminhão.
2. **Given** uma corrida em andamento, **When** o jogador está acelerando e os NPCs que não são caminhões estão ativos, **Then** todos reproduzem o som de carro, simultaneamente.
3. **Given** um veículo que estava reproduzindo som, **When** ele deixa de participar do gameplay, **Then** a reprodução é interrompida (nenhum som órfão).
4. **Given** o número máximo de veículos na pista todos produzindo som, **When** a corrida avança, **Then** ela permanece fluida, sem degradação perceptível.
5. **Given** o jogador acelerando com o som do motor ativo, **When** ele solta o acelerador ou freia — mesmo com o veículo em movimento ou parado —, **Then** o som do jogador silencia imediatamente enquanto os sons dos NPCs continuam normalmente (Clarification Q3).

---

### User Story 3 - Áudio coerente com estados, modos e interfaces (Priority: P3)

Como jogador, quero que o áudio acompanhe o estado da corrida — pausa, retomada, vitória, fim de jogo e silêncio no menu — e funcione igualmente nos três modos de dificuldade.

**Why this priority**: qualifica a experiência e evita ruído indevido, mas só se aplica sobre os sons básicos das US1 e US2.

**Independent Test**: ciclar pausa/retomada, encerrar corridas em vitória e fim de jogo, navegar menus e trocar de modo de dificuldade, verificando o comportamento sonoro em cada transição.

**Acceptance Scenarios**:

1. **Given** uma corrida pausada, **When** o jogador retoma, **Then** os sons contínuos foram suspensos na pausa e voltam a funcionar na retomada.
2. **Given** uma corrida encerrada em vitória ou fim de jogo, **When** a tela de resultado aparece, **Then** os sons dos veículos foram interrompidos de forma controlada.
3. **Given** o menu principal ou as interfaces de configuração/navegação, **When** o jogador interage com eles, **Then** nenhum som é reproduzido.
4. **Given** os três modos de dificuldade, **When** a corrida acontece em cada modo, **Then** os sons dos motores funcionam em todos eles, sem que o áudio altere velocidades nem reaplique multiplicadores.

---

### Edge Cases

- Arquivo de áudio ausente ou inválido → o jogo continua sem falha crítica; apenas aquele efeito permanece mudo.
- Número máximo de veículos na pista, todos produzindo som → a reprodução simultânea não degrada o desempenho perceptível.
- Veículo removido/reciclado em plena corrida → nenhuma reprodução continua depois da saída (sem "ecos" de veículos que já não estão na pista).
- Transição de estado no mesmo quadro (ex.: pausa imediata ao entrar em jogo) → o áudio acompanha o estado final, sem ficar preso tocando ou silenciado indevidamente.
- Sequência rápida de colisões → cada evento relevante é sinalizado sem sobreposição excessiva do mesmo efeito.
- Início e fim rápidos de corridas consecutivas → sem acúmulo de reproduções entre corridas.
- Troca de modo no menu entre corridas → os sons seguem funcionando normalmente na corrida seguinte.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE reproduzir o efeito de colisão (AUD-001) quando ocorrer uma colisão relevante entre veículos — **toda colisão veicular conta: jogador×NPC e NPC×NPC**, com o mesmo efeito sonoro em todos os casos —, acionado a partir dos eventos do sistema de colisão existente, evitando a reprodução repetitiva e excessiva do mesmo efeito durante um único evento e sem alterar a física, as consequências ou o comportamento das colisões.

- **FR-002**: O sistema DEVE reproduzir o som de motor de caminhão (AUD-002) nos caminhões NPC durante a corrida, de forma contínua enquanto o caminhão estiver ativo na pista, interrompendo a reprodução quando ele deixar de participar do gameplay e garantindo que nada continue sendo reproduzido por veículos já removidos da pista.

- **FR-003**: O sistema DEVE usar um único arquivo de som de carro (AUD-003) para o veículo do jogador e todos os NPCs que não sejam caminhões, reproduzindo o som enquanto cada um estiver ativo na corrida — de forma contínua para os NPCs; **para o jogador, apenas enquanto ele estiver acelerando** (entrada de aceleração ativa; silência ao soltar ou frear, mesmo em movimento, e nada com o veículo parado — Clarification Q3) —, e interrompendo-o quando o veículo deixar de participar do gameplay.

- **FR-004**: O sistema DEVE centralizar o gerenciamento da reprodução em um componente de áudio dedicado; iniciar, interromper e liberar os recursos corretamente; permitir que múltiplos veículos produzam sons simultaneamente respeitando os limites de desempenho; não realizar trabalho desnecessário a cada atualização do jogo; e tratar arquivos de áudio ausentes ou inválidos sem interromper a execução do jogo.

- **FR-005**: O áudio DEVE funcionar nos três modos de dificuldade da SPEC-009 — **Relaxante 1,0×, Normal 3,0× e Desafio 4,0×** —, sem modificar as velocidades dos veículos nem reaplicar os multiplicadores de dificuldade; os sons dos motores devem permanecer funcionais em qualquer velocidade efetiva; ajustes dinâmicos de volume ou de reprodução são opcionais e só se justificam para manter uma experiência sonora adequada.

- **FR-006**: O sistema DEVE reproduzir os sons de gameplay somente nos estados apropriados da corrida: na pausa, os sons contínuos dos veículos são suspensos; na retomada, voltam a funcionar; na vitória e no fim de jogo, são interrompidos de maneira controlada; e não haverá reprodução no menu principal, nas interfaces de configuração ou durante a navegação pelas interfaces.

- **FR-007**: Os três efeitos (AUD-001 colisão, AUD-002 caminhão, AUD-003 carro) DEVEM ser fornecidos em arquivos MP3 armazenados em uma pasta de áudio dentro de `assets/`, preservando os nomes dos arquivos já existentes no projeto (renomear não é obrigatório), e os sons dos motores DEVEM permitir reprodução contínua sem interrupções perceptíveis.

- **FR-008**: O sistema DEVE preservar a distinção entre caminhões e demais carros a partir das informações de tipo de veículo já existentes; reaproveitar os sistemas atuais de veículos, colisões e estados do jogo; não recriar o sistema de colisão nem a lógica de movimentação; não introduzir dependências externas; não reproduzir duplicadamente o som do mesmo veículo; e manter-se estritamente dentro do escopo desta especificação, sem introduzir os efeitos sonoros listados como fora de escopo.

### Key Entities

- **Efeito sonoro (AUD-001 a AUD-003)**: identificação do efeito, arquivo de áudio correspondente e finalidade (colisão, motor de caminhão, motor de carro).
- **Veículo sonorizado**: veículo ativo associado a um efeito de motor (caminhão ou carro), com início e fim de reprodução atrelados à sua participação no gameplay.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Os três arquivos de áudio são carregados e reproduzidos corretamente em 100% das corridas de validação (3 de 3 efeitos funcionais).
- **SC-002**: Em 100% dos eventos de colisão relevantes o efeito é reproduzido, com no máximo 1 reprodução por evento (0 repetições excessivas).
- **SC-003**: 100% dos caminhões NPC usam o som de caminhão e 100% do veículo do jogador + dos NPCs não-caminhão usam o som de carro (0 veículos com som trocado — o jogador emite AUD-003 quando acelera, conforme FR-003/Q3).
- **SC-004**: 0 reproduções permanecem ativas após veículos deixarem o gameplay (sons órfãos = 0 em todas as verificações de saída/remoção).
- **SC-005**: Os sons dos motores funcionam em 3 de 3 modos de dificuldade, com 0 alterações de velocidade ou de multiplicadores provocadas pelo sistema de áudio.
- **SC-006**: Em 100% dos ciclos pausa → retomada os sons contínuos são restaurados; após vitória ou fim de jogo, 0 sons de veículos permanecem ativos.
- **SC-007**: Durante a navegação no menu principal e nas interfaces de configuração, 0 reproduções de áudio ocorrem.
- **SC-008**: Na ausência de um arquivo de áudio (ausente ou inválido), 100% dos cenários executam o jogo sem falha crítica — apenas aquele efeito fica mudo.
- **SC-009**: Com o número máximo de veículos na pista todos produzindo som, a corrida permanece sem travamentos e sem degradação perceptível de fluidez, e 0 comportamentos pré-existentes do jogo deixam de funcionar (zero regressão de lógica).

## Assumptions

- Os três arquivos MP3 já existem em `assets/audio/` com os nomes `colisao.mp3`, `caminhao.mp3` e `carro.mp3`; eles não precisam ser renomeados.
- Escopo restrito aos 3 efeitos listados: trilha sonora, música de menu, sons de aceleração/frenagem/drift, alertas e coleta de combustível, sons de vitória/fim de jogo, controle de volume por categoria, áudio espacial avançado e efeitos por ambiente permanecem fora de escopo (§7 da descrição).
- Comportamento de pausa escolhido (a descrição delega a escolha): suspender os sons contínuos na pausa e restaurá-los na retomada.
- Os sons de gameplay são reproduzidos durante a corrida ativa — não na preparação da largada nem em menus/interfaces; o do jogador somente enquanto ele estiver acelerando (Clarification Q3).
- Inicialmente sem ajuste dinâmico de volume ou de velocidade de reprodução: loops constantes e equilibrados por veículo; ajustes dinâmicos só serão adotados se a validação demonstrar necessidade.
- Uma reprodução do efeito de colisão por evento, com supressão breve quando o mesmo evento se estende ou se repete imediatamente.
- Para preservar o desempenho, pode ser adotado um limite de sons de motor simultâneos (com prioridade ao jogador e aos veículos mais relevantes), sem alterar o comportamento dos veículos.
- O efeito de colisão é único (mesmo som e mesma percepção) para todas as colisões, sem distinção de intensidade por tipo de colisão nesta versão.
- Multiplicadores de modo conforme a SPEC-009 vigente — Relaxante 1,0×, Normal 3,0×, Desafio 4,0× (a descrição original citava 4,5× para o Desafio; ver Clarifications) —; em nenhuma hipótese o sistema de áudio altera valores de balanceamento.
- "Colisão relevante" significa uma colisão entre veículos efetivamente detectada e tratada pelos sistemas de colisão existentes (com suas consequências já definidas).
