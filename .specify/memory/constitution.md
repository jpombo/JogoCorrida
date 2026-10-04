<!--
Sync Impact Report:
- Version change: 1.1.0 → 2.0.0
- Bump rationale: MAJOR. Dois princípios MUST foram redefinidos, o que é
  incompatível com implementações que-os conforme a redação anterior:
  (1) §Traffic — o MUST "have collision detection" foi reescrito para exigir que
      o veículo de trânsito forneça identificação, posição e área ocupada, com a
      detecção e a resolução de colisão atribuídas ao SPEC-005;
  (2) §VI Multilingual Support — en-US deixa de ser exigido imediatamente e passa a
      depender de uma especificação dedicada de localização, com pt-BR como
      língua de autoria.
  A tradução integral para pt-BR (abaixo) não altera força normativa; é
  preenchimento de exigência do próprio §VI.
- Modified principles:
  - "Traffic" → "Trânsito" (MUST de detecção de colisão reescopado para SPEC-005)
  - "Multilingual Support and Documentation Language" → "Suporte Multilíngue e
    Língua da Documentação" (en-US diferido para spec de localização dedicada)
- Added sections: nenhuma seção nova. Três notas de escopo foram acrescentadas
  dentro de seções existentes (§Traffic, §VI, §Governança).
- Removed sections: nenhuma
- Modified sections (tradução pt-BR, sem mudança normativa):
  Core Principles, Core Gameplay Rules, Development Strategy and Quality Standards,
  Git and Commit Discipline, Governance
- Follow-up TODOs: nenhum token de placeholder retido. Dívida conhecida registrada:
  a especificação de localização para en-US ainda não existe e é pré-requisito
  para satisfazer integralmente o §VI.
- Deferred intent: SPEC-004 (Trânsito e Decoração) permanece bloqueada apenas por
  esta emenda; nenhuma feature foi implementada neste comando.
-->

# Constituição do JogoCorrida

## Princípios Centrais

### I. Controles Simples, Gameplay Profundo

O jogador deve entender o jogo imediatamente através de quatro controles
principais: Acelerar, Frear, Mover para a Esquerda e Mover para a Direita. O
desafio deve vir do trânsito, da velocidade, das colisões, da deriva, do
combustível e da distância — não de controles complicados nem de sistemas de jogo
desnecessários. Qualquer nova mecânica deve reforçar este princípio. Este é o
princípio orientador principal do projeto.

### II. Prioridade da Experiência do Jogador

Quando duas decisões de implementação entram em conflito, aplica-se a ordem de
prioridade: (1) experiência do jogador, (2) jogabilidade central, (3) simplicidade,
(4) manutenibilidade, (5) testabilidade, (6) performance, (7) polimento visual,
(8) sofisticação técnica. A sofisticação técnica nunca deve ser priorizada sobre uma
implementação de jogabilidade simples e confiável. Este princípio governa todas as
decisões de arquitetura e de feature.

### III. Arquitetura Modular

O projeto MUST usar uma arquitetura modular com responsabilidades separadas:
GameManager, PlayerVehicle, VehicleController, FuelSystem, CollisionSystem,
TrafficManager, TrafficVehicle, Road, TrackManager, UIManager, AudioManager. As
responsabilidades não MUST ser desnecessariamente duplicadas. Evite scripts
monolíticos — um script deve ter uma responsabilidade primária. Os sistemas MUST
se comunicar por interfaces bem definidas, sinais/eventos ou mecanismos
equivalentes da engine. Dependências diretas entre sistemas não relacionados MUST
ser minimizadas.

### IV. Design Orientado a Configuração

Parâmetros de jogabilidade MUST NOT ficar hard-coded por todo o código-fonte.
Sempre que prático, os parâmetros devem ser centralizados ou expostos por
mecanismos de configuração suportados pela engine. Exemplos incluem
player_max_speed, player_acceleration, player_brake_force, player_lateral_speed,
fuel_capacity, fuel_consumption_rate, collision_fuel_penalty, traffic_spawn_rate,
traffic_min_speed, traffic_max_speed, collision_speed_loss, drift_duration,
drift_strength. Isso permite balanceamento de jogabilidade sem modificar a lógica
central.

### V. Autoridade da Constituição e Proteção de Escopo

Este documento é a restrição primária de design e arquitetura para o
desenvolvimento assistido por IA. Agentes de IA devem verificar a consistência
com esta constitution antes de implementar qualquer feature. As seguintes features
estão FORA DE ESCOPO salvo aprovação explícita: armas, combate, multijogador,
serviços online, progressão de personagem, mecânicas de RPG, customização
complexa de veículos, simulação realista de veículos, exploração de mundo aberto,
economia complexa, mundos gerados proceduralmente, inteligência artificial que
exija aprendizado de máquina, controles adicionais de jogador. Features futuras
podem ser adicionadas por decisões explícitas do projeto, mas MUST NOT ser
assumidas pelo agente de IA.

### VI. Suporte Multilíngue e Língua da Documentação

O jogo MUST ter **Português do Brasil (pt-BR)** como língua de autoria e padrão, e
deve passar a suportar **Inglês dos EUA (en-US)** por meio de uma especificação
dedicada de localização. Até que essa especificação exista, pt-BR é a única língua
obrigatória para texto voltado ao usuário, e nenhuma feature MUST ser bloqueada
por ausência de strings em en-US. O suporte a en-US MUST ser planejado: features
que introduzam texto de usuário SHOULD manter os textos externalizados, sem
embutir literais nos scripts, para permitir a localização futura sem refatoração.

Para desenvolvimento, TODA a documentação escrita, comentários, mensagens de
commit e comunicações de projeto MUST ser mantidas em Português do Brasil (pt-BR).
Isso se aplica a todos os artefatos do projeto, **incluindo esta constitution**,
specs, planos, tasks e quaisquer entregáveis escritos. Isso garante comunicação
consistente entre a equipe e alinha o projeto à identidade cultural e linguística
do projeto.

## Regras Centrais de Jogabilidade

O jogo é um jogo de corrida arcade 2D com perspectiva de cima e estética pixel-art.
O jogador controla um veículo que se desloca continuamente por uma estrada e deve
alcançar o fim de cada pista antes de ficar sem combustível. O foco está em:
controle de direção, desvio de trânsito, consequências de colisão, gestão de
combustível, progressão de pista e aumento de dificuldade.

### Veículo do Jogador

O veículo do jogador MUST: mover-se para a esquerda e para a direita dentro dos
limites da estrada; acelerar; frear; ter uma velocidade máxima configurável; ter
parâmetros de aceleração e frenagem configuráveis; consumir combustível enquanto se
move; reagir a colisões com outros veículos. O veículo MUST NEVER sair da área
válida da estrada. Os limites da estrada MUST ser representados por um sistema
explícito de colisão ou de fronteira, e não apenas por posicionamento visual.

### Física do Veículo

O jogo é um jogo de corrida arcade e MUST NOT tentar simular física realista de
veículos. A física MUST priorizar: responsividade, previsibilidade, simplicidade,
diversão e comportamento consistente. O veículo deve ter uma sensação de
inércia configurável. Aceleração e frenagem SHOULD influenciar a velocidade
frontal. O movimento lateral SHOULD ser responsivo, mas sem se comportar como um
simulador de corrida realista.

### Comportamento de Colisão

Uma colisão com outro veículo MUST NOT resultar imediatamente em Game Over. Uma
colisão MUST produzir uma consequência perceptível de jogabilidade. No mínimo, uma
colisão MUST: reduzir a velocidade do veículo; produzir um efeito temporário de
deriva/deslizamento; consumir combustível adicional; fornecer feedback visual;
fornecer feedback sonoro quando o áudio for implementado. O efeito de deriva MUST
ser configurável e isolado da lógica principal de controle do veículo. O sistema de
colisão MUST suportar balanceamento futuro sem exigir mudanças arquiteturais.
Exemplos de parâmetros configuráveis: collision_speed_loss, collision_fuel_loss,
drift_duration, drift_strength, drift_recovery, collision_cooldown.

### Sistema de Combustível

Combustível é um recurso fundamental de jogabilidade. O jogador MUST completar a
pista antes que o combustível chegue a zero. O consumo de combustível MUST ser
configurável. No mínimo: fuel_capacity, fuel_consumption_rate,
collision_fuel_penalty. O consumo de combustível SHOULD ser influenciado pelo
movimento do veículo. O sistema MUST impedir que os valores de combustível se
tornem negativos. Quando o combustível chega a zero, o veículo não pode mais
prosseguir normalmente e o jogo entra no estado de falha apropriado. O sistema de
combustível MUST ser independente da interface de usuário. A UI SHOULD observar o
sistema de combustível em vez de modificar diretamente seu estado interno.

### Pista

A pista é finita na jogabilidade normal. Cada pista tem: Início, Fim, limites da
estrada, estrutura de faixas, Trânsito, Distância/progressão. O objetivo primário
é: INICIAR → DIRIGIR → DESVIAR DO TRÂNSITO → GERENCIAR COMBUSTÍVEL → CHEGAR AO
FINAL. A vitória ocorre quando o jogador alcança o fim da pista com combustível
suficiente. A falha ocorre quando o jogador não consegue continuar por
esgotamento de combustível ou outra condição de falha explicitamente definida.

### Trânsito

O trânsito consiste inicialmente em: carros de passeio e caminhões. Veículos de
trânsito MUST: surgir segundo regras configuráveis; mover-se em relação ao
progresso do jogador; permanecer dentro da área válida da estrada; ter velocidade
configurável; ter dimensões configuráveis; **e fornecer a identificação, a posição
e a área ocupada exigidas por um sistema de colisão**. A detecção e a resolução de
colisão são introduzidas pelo SPEC-005. Até lá, veículos de trânsito MUST NOT
detectar nem resolver colisões, e nenhuma feature de spec anterior à colisão pode
exigir esse comportamento. A geração de trânsito MUST ser separada do comportamento
individual dos veículos. Um Traffic Manager/Spawner SHOULD controlar a criação e a
remoção do trânsito. Veículos individuais não devem ser responsáveis por gerenciar
todo o sistema de trânsito.

### Dificuldade

A dificuldade MUST ser orientada por dados/configuração sempre que prático. A
dificuldade MAY aumentar através de: número de veículos de trânsito, densidade de
trânsito, velocidade dos veículos, frequência de caminhões, largura da estrada,
comprimento da pista, combustível disponível, consequências de colisão. A
dificuldade MUST NOT ser aumentada por meio de complexidade de controles
desnecessária. Os quatro controles principais do jogador MUST permanecer
inalterados.

### Câmera e Apresentação

O jogo usa uma perspectiva 2D de cima. O veículo do jogador permanece
aproximadamente centralizado na área de jogabilidade enquanto o mundo/estrada se
move em relação ao jogador. O estilo visual é pixel art. A implementação MUST
preservar as características de pixel-art: renderização alinhada a pixels onde
apropriado, resolução de sprite consistente, sem suavização desnecessária, escala
de pixel consistente e proporções visuais consistentes. Arte não MUST ditar a
arquitetura de jogabilidade. Sistemas de jogabilidade MUST permanecer independentes
de sprites específicos.

### Estado de Jogo

O jogo MUST representar explicitamente seus estados principais. No mínimo: MENU,
READY, PLAYING, PAUSED, VICTORY, GAME_OVER. Transições de estado MUST ser
controladas por um mecanismo central de estado de jogo. Objetos de jogabilidade
individuais MUST NOT decidir independentemente o estado global do jogo.

## Estratégia de Desenvolvimento e Padrões de Qualidade

### Estratégia de Desenvolvimento

O desenvolvimento MUST seguir uma abordagem incremental de fatia vertical. NÃO
implemente o jogo completo antes de validar a jogabilidade central. Ordem de
desenvolvimento recomendada: Fase 1 — Movimento Central (Estrada, veículo do
jogador, movimento esquerda/direita, Aceleração, Frenagem, limites da estrada,
câmera/movimento básico do mundo); Fase 2 — Trânsito (surgimento de trânsito,
carros, caminhões, movimento de trânsito, detecção de colisão); Fase 3 —
Consequências de Colisão (Redução de velocidade, Deriva, Penalidade de
combustível, Feedback visual); Fase 4 — Combustível (Capacidade de combustível,
Consumo de combustível, HUD de combustível, esgotamento de combustível, Game
Over); Fase 5 — Conclusão da Pista (Distância da pista, Progressão, Linha de
chegada, estado de Vitória); Fase 6 — Dificuldade (Densidade de trânsito,
diferentes velocidades de veículos, Caminhões, variações de pista, dificuldade
progressiva); Fase 7 — Apresentação (assets pixel-art, Animações, efeitos
sonoros, Música, polimento de UI, Efeitos).

### Regras para Desenvolvimento Assistido por IA

Agentes de IA são assistentes de desenvolvimento e MUST NOT redefinir
autonomamente o design do jogo. Antes de implementar uma feature, o agente MUST
verificar se ela é consistente com esta constitution. Se uma implementação
solicitada entrar em conflito com a constitution, o agente MUST identificar o
conflito antes de modificar a arquitetura. O agente MUST priorizar: convenções
existentes do projeto, componentes reutilizáveis existentes, soluções simples,
soluções modulares, mudanças mínimas. O agente MUST evitar abstração desnecessária.
NÃO criar frameworks, sistemas ou padrões de projeto apenas porque sejam
tecnicamente possíveis.

### Disciplina de Mudanças

Cada tarefa de desenvolvimento MUST ter um escopo claramente definido. O agente
MUST evitar modificar sistemas não relacionados. Ao implementar uma feature:
Entender → Inspecionar código existente → Identificar sistemas afetados →
Implementar a mudança mínima necessária → Executar testes → Validar jogabilidade →
Revisar mudanças. NÃO reescrever sistemas funcionais sem um motivo específico. NÃO
introduzir mudanças arquiteturais incompatíveis durante pequenas tarefas de feature.

### Testes

Todo sistema de jogabilidade SHOULD ser testável de forma independente sempre que
prático. No mínimo, testes automatizados SHOULD cobrir lógica determinística
crítica como: consumo de combustível, esgotamento de combustível, penalidade de
combustível por colisão, redução de velocidade, progressão da pista, condição de
vitória, condição de game over, restrições de limite da estrada. Testes MUST ser
executados após mudanças significativas em sistemas de jogabilidade. Todo sistema
com lógica determinística de spawn, reciclagem, seleção ou posicionamento — como o
trânsito e a decoração lateral — MUST ter cobertura automatizada.

### Qualidade de Código

O código MUST priorizar legibilidade sobre esperteza. Use nomes descritivos.
Evite: números mágicos, estado global mutável, lógica duplicada, funções
monolíticas grandes, herança desnecessária, dependências desnecessárias, código
morto, código de depuração temporário em sistemas de produção. Comentários SHOULD
explicar POR QUE algo existe quando o motivo não é óbvio. NÃO escrever comentários
que apenas repitam o que o código já diz.

### Performance

O jogo é um jogo arcade 2D. A otimização de performance MUST permanecer
proporcional às necessidades reais. NÃO otimizar prematuramente. Evite criação
desnecessária de objetos a cada quadro; reutilize objetos sempre que prático;
remova veículos de trânsito que não sejam mais relevantes; evite processamento
caro em laços de `_process`/por quadro quando uma lógica orientada a eventos seja
suficiente; mantenha a detecção de colisão limitada aos objetos relevantes de
jogabilidade. Decisões de performance MUST NOT complicar desnecessariamente a
arquitetura.

### Independência de Assets

A lógica de jogabilidade MUST NOT depender diretamente de arte específica. O
veículo do jogador tem responsabilidades separadas para jogabilidade, colisão, física e
representação visual. Trocar o sprite do jogador MUST NOT exigir reescrever a
física do veículo. O mesmo princípio se aplica a veículos de trânsito, gráficos da
estrada, UI e efeitos. A classificação de um asset para fins de jogabilidade — por
exemplo, se um elemento decorativo pode se repetir — MUST ser um dado de
configuração e MUST NOT ser deduzida do nome do arquivo em tempo de execução.

### Definição de Concluído

Uma feature é considerada concluída SOMENTE quando: a implementação funciona; a
funcionalidade existente continua funcionando; os testes automatizados relevantes
passam; nenhum erro evidente está presente em execução; a implementação segue esta
constitution; nenhuma complexidade arquitetural desnecessária foi introduzida; o
diff Git contém apenas mudanças relacionadas à tarefa.

## Disciplina de Git e Commit

Cada mudança significativa SHOULD produzir um commit Git focado. Commits SHOULD
representar uma mudança coerente. Exemplos: feat: add player vehicle movement;
feat: add road boundary collision; feat: add traffic spawning; feat: add vehicle
collision response; feat: add fuel consumption; feat: add track completion; fix:
prevent player from leaving road; test: add fuel system tests. Evite misturar
mudanças não relacionadas no mesmo commit. NÃO commitar artefatos de build
gerados, arquivos temporários, arquivos específicos de IDE ou segredos.

## Governança

Esta constitution é a restrição primária de design e arquitetura para este projeto
em desenvolvimento assistido por IA. Ao implementar uma feature, o agente de IA
MUST considerar esta constitution antes de tomar decisões de arquitetura ou de
jogabilidade. O agente de IA MUST NOT alterar silenciosamente a constitution para
acomodar uma implementação. Se um requisito não puder ser satisfeito sem violar a
constitution, o conflito MUST ser reportado antes da implementação. A constitution
MAY evoluir, mas mudanças MUST ser intencionais, documentadas e versionadas.

**Procedimento de emenda**: Alterações na constitution MUST passar por
`/speckit.constitution`, MUST bumps de versão segundo a política abaixo, MUST gerar
um Sync Impact Report no topo do arquivo e SHOULD incluir um teste de regressão em
`tests/unit/test_constitution.gd` quando a alteração afetar um MUST verificável.
Princípios não podem ser removidos, redefinidos ou diluídos para acomodar uma
implementação específica.

**Política de versionamento**: MAJOR quando houver remoção ou redefinição de um
princípio MUST, ou mudança incompatível de governança; MINOR quando um novo
princípio/seção for adicionado ou a orientação for expandida materialmente; PATCH
para esclarecimentos, correções de redação ou refinamentos não semânticos. A data
de ratificação é imutável; a data da última emenda é a data da alteração atual, em
formato ISO AAAA-MM-DD.

**Revisão de conformidade**: Todos os PRs/reviews devem verificar conformidade com
esta constitution. Complexidade MUST ser justificada. Usar este documento como a
referência primária para orientação de desenvolvimento em execução. Specs que
conflitem com um MUST MUST ser corrigidas na spec, no plano ou nas tasks — nunca
por reinterpretação do princípio. Uma spec em conflito é bloqueada para
implementação até que o conflito seja resolvido por emenda da constitution ou por
correção da spec.

**Dívida Conhecida**: o suporte a en-US (inglês dos EUA) ainda não foi
implementado; a especificação de localização dedicada é pré-requisito para
satisfazer integralmente o §VI. Nenhuma feature pode ser bloqueada por essa dívida.

**Version**: 2.0.0 | **Ratifiada**: 2026-09-18 | **Última Emenda**: 2026-10-02