# Specification Quality Checklist: Sistema de Trânsito e Decoração dos Ambientes

**Purpose**: Validar completude e qualidade da especificação antes de prosseguir para planejamento
**Created**: 2026-09-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Itens marcados como completos: todos os 16 itens passam na validação. A especificação passou por 4 rodadas de esclarecimentos e está pronta para `/speckit.plan`.
- A especificação contém 8 histórias de usuário priorizadas (P1: US1, US2, US3, US8; P2: US4, US5; P3: US6, US7), 62 requisitos funcionais (FR-001 a FR-062), 27 critérios de sucesso (SC-001 a SC-027), 8 entidades-chave e 20 casos de borda.
- **Sessão de esclarecimentos (1ª rodada, 2026-09-30)**: os 3 marcadores `[NEEDS CLARIFICATION]` foram resolvidos e registrados na seção **Clarifications** da spec.
- **Validação do comportamento de movimentação (2ª rodada, 2026-09-30)**: todos os pontos levantados foram verificados contra a spec e um foi corrigido por ser divergente.

  **Decoração — comportamento validado:**

  | Comportamento solicitado | Onde está registrado | Status |
  | --- | --- | --- |
  | Criada fora da área visível (topo da tela) | FR-041, US5 cenário 3 | Conforme |
  | Durante a aceleração do jogador, move para baixo | FR-040, US5 cenário 1 | Conforme |
  | Removida da cena quando fica completamente invisível | FR-043, SC-010 | Conforme |
  | Com o jogador parado, nenhuma decoração se move | FR-040, US5 cenário 2, SC-022 | Conforme |
  | Nunca postada sobre a estrada | FR-031, FR-042, FR-051, SC-021 | Conforme (incluída a posição de criação acima da área do jogo) |

  **Veículos — comportamento validado:**

  | Comportamento solicitado | Onde está registrado | Status |
  | --- | --- | --- |
  | Criado fora da área visível, no topo, dentro da área da estrada | FR-013, FR-014, FR-009 | Conforme |
  | Respeita a diferença de largura de 2 para 4 vias na criação | FR-014, US1 cenário 9 | **Corrigido — requisito novo** |
  | Velocidade sempre inferior à do jogador | FR-008 | Conforme |
  | Durante a aceleração, entra na área visível e é ultrapassado | FR-007, US1 cenário 2 | Conforme |
  | Ultrapassado e saindo pelo final da tela, marcado para remoção | FR-015, US1 cenário 3 | **Corrigido — requisito novo** |
  | Sem acelerar, mantém o deslocamento normal e sobe até o topo, ficando invisível | FR-007, FR-016, US1 cenários 4 e 5 | **Corrigido — inconsistência sanada** |
  | Nunca se move fora da área da estrada e respeita 2 → 4 vias | FR-009, FR-020, US1 cenário 9, US3 | Conforme |

- **Correção mais relevante**: a 1ª rodada havia fixado em FR-008 que "os veículos nunca se deslocam para cima em relação à tela". Isso é incorreto e foi corrigido. A velocidade *máxima* do jogador é maior que a dos veículos, mas a velocidade *atual* do jogador pode ficar abaixo da velocidade de um veículo já em cena — nesse caso o veículo sobe na tela. Isso foi registrado em FR-006, FR-007, FR-016, SC-003, na premissa correspondente e em dois casos de borda novos (inversão da direção relativa e veículo exatamente sobre a borda da tela).
- **Esclarecimentos do `/speckit.clarify` (3ª rodada, 2026-09-30)**: 4 ambiguidades materiais foram identificadas na varredura de cobertura e resolvidas, Resultando em 5 requisitos funcionais e 4 critérios de sucesso novos. Todas as referências FR desta nota foram remapeadas para a numeração vigente.

  | Questão | Resposta | Onde está registrado | Status |
  | --- | --- | --- | --- |
  | Veículo em faixa que deixa de existir na redução de 4 para 2 vias | Reposicionamento contínuo para a faixa válida mais próxima | FR-020, caso de borda "Reatribuição de faixa durante o estreitamento", US3 cenário 6, SC-023 | **Lacuna sanada** |
  | Meta de desempenho com trânsito e decoração simultâneos | 60 FPS como meta, 30 FPS como piso, sem quedas recorrentes | FR-058, SC-024, US5 cenário 7, premissa de desempenho | **Lacuna sanada** |
  | Conjunto reutilizável esgotado | Criar novo objeto sob demanda e incorporá-lo ao conjunto | FR-018 (trânsito), FR-045 (decoração), caso de borda "Conjunto reutilizável esgotado", SC-025 | **Lacuna sanada** |
  | Sobreposição visual entre elementos decorativos | Permitida na direção lateral; espaçamento mínimo aplica-se só à direção de deslocamento | FR-039, caso de borda "Sobreposição visual entre elementos decorativos", SC-026, US4 cenário 8 | **Contradição removida** |

  **Conflitos resolvidos nesta rodada** (texto anterior substituído, não duplicado): o caso de borda "Espaço insuficiente para o espaçamento mínimo" foi reescrito como "Espaço longitudinal insuficiente" para não sugerir restrição lateral; o caso de borda "Densidade configurada acima da capacidade da tela" passou a distribuir o excedente nas profundidades disponíveis em vez de "evitar sobreposição"; a lista de parâmetros de decoração passou a declarar o espaçamento como longitudinal.

- Verificação de integridade: IDs de FR (001–062) e SC (001–027) sequenciais e sem duplicatas; 0 marcadores `[NEEDS CLARIFICATION]`; assets de decoração referenciados conferem com `assets/decoracao/{planice,deserto,floresta,gelo}/` (5 + 5 + 4 + 3 arquivos, desde 2026-10-03); assets de veículos conferem com `assets/npcs/` (17 arquivos PNG: 1 caminhão e 16 carros), assumidos como conjunto inicial configurável.
- Atualização de assets (2026-10-02): os assets de decoração foram substituídos — todos os `.jpeg` foram removidos e as bibliotecas passaram a ser compostas por `.png`. Nomes e quantidade de elementos por ambiente mudaram: Planície 11 → 5 (sem moinho), Deserto 8 → 5 (sem rochas), Floresta 6 → 4 (sem cogumelos), Gelo 5 → 4 (dois bonecos de neve fundidos em `gelo_boneco.png`). A tabela de FR-029, a descrição e os cenários da US4 e a premissa de formato foram atualizados.
- Exceção de repetição (2026-10-02): autorizado que elementos decorativos com a string `arvore` no nome do asset se repitam consecutivamente até 10 vezes **por lado da estrada**, formando agrupamentos naturais. Registrado em FR-036, SC-014, no caso de borda "Repetição consecutiva de elementos de árvore" e em premissa. Os demais elementos mantêm a proibição de repetição imediata. Com bibliotecas de 4 a 5 arquivos, essa exceção é o que torna a densidade visual viável nos ambientes com menos elementos.
- **Esclarecimentos do `/speckit.clarify` (4ª rodada, 2026-10-02)**: 4 ambiguidades materiais foram identificadas na varredura de cobertura e resolvidas, Resultando em 1 critério de sucesso novo (SC-027) e 1 caso de borda novo. Um defeito de numeração foi corrigido (dois cenários numerados "7" na US5).

  | Questão | Resposta | Onde está registrado | Status |
  | --- | --- | --- | --- |
  | Escala dos assets de decoração muito maiores que o mundo do jogo | Reescalonar com filtro de vizinho mais próximo na implementação, exibir em escala 1.0 | FR-046, FR-047, caso de borda "Reescalonamento dos assets de decoração", SC-027, premissa de uso dos assets | **Contradição sanada** |
  | Composição da pasta de veículos de trânsito | Todos os 17 assets; van renomeada para `Carro-prata.png`, spritesheet removido e pasta subdividida por categoria | premissa de assets de veículos, FR-011, FR-012, FR-001 | **Lacuna sanada** |
  | Escopo do contador de repetição de `arvore` | Por lado da estrada, somando todas as profundidades desse lado | FR-036, SC-014, caso de borda "Repetição consecutiva de elementos de árvore", premissa | **Ambiguidade sanada** |
  | Destino da decoração existente com o jogador parado | Permanecem congeladas na tela; sem criação e sem remoção até o jogador voltar a se mover | FR-040, FR-041, caso de borda "Velocidade zero", SC-022 | **Ambiguidade sanada** |
- Risco residual: a densidade visual da decoração passou a depender de 3 a 5 assets por ambiente (3 no Gelo desde 2026-10-03), contra 5 a 11 antes. A SC-009 (pelo menos 3 elementos visíveis por lado) e a SC-026 (espaçamento longitudinal mínimo por profundidade) continuam válidas, mas devem ser verificadas com atenção durante a implementação, pois a redução da biblioteca limita as combinações disponíveis por profundidade.
- **Categorização e velocidades dos veículos (2026-10-02)**: `assets/npcs/` foi subdividida em quatro subpastas que representam as categorias de veículo — `caminhao/` (1 asset, 90 km/h), `esporte/` (3 assets, 120 km/h), `passeio/` (6 assets, 100 km/h) e `utilitario/` (7 assets, 90 km/h) — e a velocidade máxima do jogador foi fixada em 125 km/h. Atualizados: FR-001, FR-008, FR-010, FR-011, FR-012 (com tabela categoria → pasta → velocidade → assets → dimensão), FR-023, FR-061, FR-062, a US2 (agora sobre as quatro categorias), SC-004, a entidade **Veículo de Trânsito** e as premissas. A numeração de FR e SC foi preservada; nenhum requisito foi acrescentado ou removido.
- Decisão de unidade (2026-10-02): os valores em km/h são registrados como **referência de projeto** e não alteram o `max_speed=100` em unidades abstratas do SPEC-001, evitando invalidar os critérios SC-002 a SC-004 daquele spec. A conversão entre as duas unidades fica a cargo do `/speckit.plan`.
- Risco residual: a margem entre a categoria mais rápida (`esporte`, 120 km/h) e o jogador (125 km/h) é de apenas 4%, o que torna a ultrapassagem desse veículo muito lenta em termos de distância percorrida. Registrado como caso de borda "Margem estreita entre `esporte` e o jogador".
- Risco residual (2026-10-02, `/speckit.plan`): a verificação das dimensões reais dos 18 assets de decoração mostrou que **11 deles não são divisíveis por nenhum fator inteiro maior que 1** — `deserto_cactus` (457x175), `deserto_ruina` (801x551), `floresta_arvore02` (625x628), `floresta_lago` (622x551), `floresta_serralheria` (608x483), `gelo_casa02` (422x527), `planice_arvore01` e `planice_casa01` (487x518), `planice_feno01` (704x701), `planice_milho` (1072x487) e `planice_silo01` (698x699) — e todos são totalmente opacos, sem margem transparente recortável. A decisão da 4ª rodada (fator inteiro) era, portanto, inaplicável e foi corrigida para "reescalonar com filtro de vizinho mais próximo, exibir em escala 1.0". O único asset com proporção muito horizontal (`planice_milho`, 1072x487) exigirá atenção na escolha da altura-alvo, para não ocupar a lateral inteira da tela. Gate de planejamento bloqueado até a correção; resolvido com a aprovação do usuário.
- **Atualização dos assets de decoração (2026-10-03)**: os 17 PNGs foram reexportados fora do jogo com proporções derivadas da **base de tile 32x32**, substituindo a caixa 200x112 de R1. Renomeações: `deserto_coqueiro01` → `deserto_arvore01`, `deserto_coqueiro02` → `deserto_arvore02`, `deserto_ruina` → `deserto_casa`, `floresta_serralheria` → `floresta_serra`; `gelo_casa02` saiu da biblioteca (`ICE` passa a ter 3 assets). Repetíveis: os 6 assets `arvore` (`planice_arvore01`, `deserto_arvore01`, `deserto_arvore02`, `floresta_arvore01`, `floresta_arvore02`, `gelo_arvore`). SC-027 corrigida de 15%–60% para **3%–35%** da área visível (16 px a 160 px); SC-020, FR-047, o caso de borda "Reescalonamento dos assets de decoração" e a premissa de uso dos assets passam a admitir o ajuste de proporção para a grade de 32 px (4 assets ajustados: `planice_milho` 30,4%, `deserto_cactus` 23,4%, `planice_casa01` 21,7%, `planice_arvore01` 7,9%). Atualizados: `spec.md` (tabela FR-029, FR-047, SC-020, SC-027, contextos de decoração, premissa e caso de borda), `data-model.md` §4, `research.md` R1 e R6, `plan.md`, `quickstart.md` e `GameConfig.DECORATION_LIBRARIES`; `tools/resize_decoration_assets.py` passou a validar sem escrever. **`.import`**: os 17 arquivos foram gerados ao abrir o editor Godot; `*.import` é ignorado pelo `.gitignore`, então é preciso abrir o editor uma vez por máquina antes dos testes headless.
- **Percentuais de apresentação das decorações (2026-10-03)**: cada entrada de `GameConfig.DECORATION_LIBRARIES` ganhou o campo `weight` (pontos percentuais que somam 100 por ambiente) e o sorteio em `DecorationManager._escolher_asset` passou a ser ponderado entre os candidatos elegíveis, mantendo D6/D7/SC-014 intactos. Alvos: Planície árvore 80% / casa 5% / feno 7% / milho 6% / silo 2%; Deserto árvores 73% (36,5 + 36,5) / cactus 20% / duna 5% / casa 2%; Floresta árvores 96% (48 + 48) / lago 3% / serra 1% (o dado original de 85% somava 89% e foi fechado nas árvores, com aprovação do usuário); Gelo árvore 96% / boneco 3% / casa 1%. Atualizados: FR-036 e FR-037 (`spec.md`), `data-model.md` §4, `DecorationData.weight`, o validador (falha se a biblioteca não somar 100) e o cenário V17 do `quickstart.md`. Sem teto de elementos ativos: a contagem continua implícita no espaçamento × 3 profundidades × 2 lados, e árvores do mesmo nível já ocupam colunas distintas (uma por profundidade), com sobreposição lateral permitida pela FR-038.
- **Compensação do viés de repetição (2026-10-03)**: simulação de 500 mil nascimentos por ambiente (0 violações de D6) mostrou que D6 e D7 deslocam a frequência observada do percentual declarado — sem compensação, `deserto_cactus` saía com 16,6% para 20% declarados e `gelo_arvore` com 89,2% para 96%. Decisão do usuário: compensar internamente em vez de subir `decoration_tree_repeat_limit`. Assim `weight` permanece a meta declarada em configuração (soma 100, conferida pelo validador) e `DecorationManager._compensar_pesos` deriva `DecorationData.peso_sorteio`, o peso efetivo usado no sorteio, que corrige o viés médio das regras. Resultado da simulação: desvio máximo de 0,4 p.p. em Planície, Deserto e Floresta; em Gelo a árvore fica em ~90,3%, perto do teto de cerca de 90,9% (10 de cada 11 nascimentos) que SC-014 impõe a qualquer biblioteca com uma única árvore repetível, e o excedente aparece em `gelo_boneco` ~7,3% e `gelo_casa01` ~2,4%. Atualizados: `DecorationData.peso_sorteio`, `DecorationManager._compensar_pesos` e `_sortear_ponderado`, FR-036 (ressalva do teto e lista completa dos 6 `repeatable`), `data-model.md` §4, `research.md` R11 e o cenário V17 do `quickstart.md`.
- Conformidade com a constituição (v2.0.0): respeitados os princípios de arquitetura modular (FR-055, FR-022, FR-054), design orientado a configuração (FR-023, FR-057), independência de assets (FR-012), preservação de pixel art (FR-049), reúso de objetos e remoção de elementos irrelevantes (FR-017, FR-044) e separação entre os conjuntos de veículos e de decoração (FR-044).
- Colisões, dano, drift, combustível, vitória/derrota, dificuldade dinâmica e trânsito em sentido contrário foram explicitamente excluídos (FR-062 e seção **Fora de Escopo**).
- **Validação final da implementação (T053, 2026-10-04)**: suíte completa executada em Godot 4.7.2 + GdUnit4 headless — **13 suítes, 112 casos, 0 erros, 0 falhas** (exit 101 do runner), incluindo as 10 suítes do SPEC-004 (agora com `test_constitution`, T066), as coberturas novas de SC-023 (T064), SC-003 (T065) e proporção de categorias (T062), e a 6ª propriedade de FR-002 (direção, T063). Desempenho (T048: ~0,4–0,5 ms/quadro para os dois sistemas nos 4 ambientes) e estabilidade de memória (T049: pools estagnados após 10 minutos) reprovados. Os 17 cenários V1–V17 do `quickstart.md` estão registrados na Parte 5, todos ✅.
- **Imutabilidade dos specs anteriores (T053)**: `git diff` confirma `src/environment/` e `src/game/game_state.gd` **sem nenhuma alteração**; `src/road/road.gd` e `src/player/player_vehicle.gd` receberam **uma linha cada** (`class_name Road` / `class_name PlayerVehicle`), exigência dos dublês de teste e exceção **justificada formalmente** pela T060 em `plan.md` e `tasks.md` — declaração de tipo, sem mudança de comportamento, e a asserção correspondente ao FR-051/FR-052 segue coberta por `test_spec004_regression.gd` e `test_no_collision.gd`.
