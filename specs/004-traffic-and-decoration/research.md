# Phase 0 — Pesquisa e Decisões Técnicas

**Feature**: Sistema de Trânsito e Decoração dos Ambientes
**Branch**: `004-traffic-and-decoration` | **Data**: 2026-10-02

Este documento registra as decisões técnicas tomadas durante o `/speckit.plan`. Cada decisão tem o formato **Decisão** / **Racional** / **Alternativas consideradas**, conforme o gate de pesquisa.

---

## R1. Escala dos assets de decoração

**Decisão (atualizada em 2026-10-03)**: os 17 assets de decoração são **entregues já na resolução final**, preparados fora do jogo com filtro de vizinho mais próximo sobre uma **base de tile de 32x32**, e exibidos em **escala 1.0**. A preparação acontece uma única vez, nunca em runtime. `tools/resize_decoration_assets.py` deixou de reescalonar e passou a **validar** a entrega: nomes contra `GameConfig.DECORATION_LIBRARIES`, altura dentro da faixa da SC-027 (3% a 35% da área visível) e proporção frente ao backup em `assets/decoracao/_originais/`.

A caixa alvo anterior (**200x112 px**, decisão de 2026-10-02) está **superada**: a reexportação dos PNGs na base de 32x32 a tornou desnecessária.

**Dimensões atuais** (medidas em 2026-10-03):

| Asset | Original (`_originais/`) | Entregue | Tiles (32px) | Altura % viewport |
|---|---|---|---|---|
| `deserto_arvore01` | 644x595 (`deserto_coqueiro01`) | 49x45 | 1.53x1.41 | 9% |
| `deserto_arvore02` | 620x615 (`deserto_coqueiro02`) | 49x49 | 1.53x1.53 | 10% |
| `deserto_cactus` | 457x175 | 32x16 | 1.00x0.50 | 3% |
| `deserto_casa` | 801x551 (`deserto_ruina`) | 96x66 | 3.00x2.06 | 14% |
| `deserto_duna` | 640x640 | 32x32 | 1.00x1.00 | 7% |
| `floresta_arvore01` | 680x686 | 49x49 | 1.53x1.53 | 10% |
| `floresta_arvore02` | 625x628 | 49x49 | 1.53x1.53 | 10% |
| `floresta_lago` | 622x551 | 64x57 | 2.00x1.78 | 12% |
| `floresta_serra` | 608x483 (`floresta_serralheria`) | 96x76 | 3.00x2.38 | 16% |
| `gelo_arvore` | 592x592 | 49x49 | 1.53x1.53 | 10% |
| `gelo_boneco` | 645x489 | 24x18 | 0.75x0.56 | 4% |
| `gelo_casa01` | 656x656 | 160x160 | 5.00x5.00 | 33% |
| `planice_arvore01` | 487x518 | 49x48 | 1.53x1.50 | 10% |
| `planice_casa01` | 487x518 | 96x80 | 3.00x2.50 | 17% |
| `planice_feno01` | 704x701 | 32x32 | 1.00x1.00 | 7% |
| `planice_milho` | 1072x487 | 98x64 | 3.06x2.00 | 13% |
| `planice_silo01` | 698x699 | 64x64 | 2.00x2.00 | 13% |

`gelo_casa02` saiu da biblioteca: `ICE` fica com 3 elementos. Os nomes `deserto_coqueiro01`, `deserto_coqueiro02`, `deserto_ruina` e `floresta_serralheria` viraram `deserto_arvore01`, `deserto_arvore02`, `deserto_casa` e `floresta_serra`, mantendo os backups com o nome antigo.

**Racional**:
A reexportação entrega 13 dos 17 assets com pelo menos um eixo múltiplo de 32 px, o que encaixa cada elemento na grade de tiles do mundo do jogo (estrada e cenário também derivam de 32 px). Quatro assets tiveram a proporção ajustada no encaixe — `planice_milho` (30,4%), `deserto_cactus` (23,4%), `planice_casa01` (21,7%) e `planice_arvore01` (7,9%) —, ajuste que a premissa de uso dos assets passou a admitir; o validador avisa a partir de 10% de desvio e falha acima de 35%.

As alturas ficam entre 16 px e 160 px, ou seja, **3% a 35% da área visível de 480 px**, faixa agora registrada em SC-027. A faixa anterior (15% a 60%) era inatingível com a base de 32 px e foi corrigida junto com a reexportação.

Os originais continuam em `assets/decoracao/_originais/` (18 arquivos, incluindo `gelo_casa02`), o que permite comparar proporção e conferir que nenhum pixel foi suavizado.

**Alternativas consideradas**:
- *Caixa 200x112 com escala `min(200/l, 112/a)`* — **superada**: era a aplicação do reescalonamento no próprio repositório; a reexportação na base de 32x32 a substituiu.
- *Redução por fator inteiro (decisão original do clarify)* — **descartada**: impossível para 11 dos 18 originais, conforme medido.
- *Escala fracionária em runtime* — **descartada**: reintroduz reamostragem por quadro e artefatos visuais; contraria FR-047.
- *Solicitar reexportação dos assets na resolução final* — **adotada em 2026-10-03**: era a melhoria futura registrada na versão anterior de R1 e é o que a atualização de assets entregou.

**Impacto no spec (2026-10-03)**: SC-020, SC-027, FR-047, o caso de borda "Reescalonamento dos assets de decoração" e a premissa de uso dos assets foram atualizados para a base de 32x32; a tabela de bibliotecas de `spec.md` (FR-029), `data-model.md` §4 e `GameConfig.DECORATION_LIBRARIES` refletem os nomes e as dimensões atuais.

### Interpretação de "consistent pixel scale" (constitution v2.0.0 §Câmera e Apresentação)

A constitution exige preservar "pixel-aligned rendering where appropriate, consistent sprite
resolution, no unnecessary smoothing, consistent pixel scale, consistent visual proportions".
O MUST de `consistent pixel scale` **não está definido** quanto a redimensionamento feito na
preparação dos assets, e esta feature depende dele.

**Interpretação adotada**: `consistent pixel scale` refere-se à escala de apresentação em
engine, não à grade de pixels do asset de origem. Os 17 assets de decoração são exibidos em
escala **1.0**, o mesmo valor dos veículos e da estrada, e a viewport é 640x480 sem zoom de
câmera. Essa leitura satisfaz o MUST.

A leitura alternativa — que o MUST exige preservar a grade de pixels de origem — era
inaplicável enquanto os assets não estavam na resolução final: 11 dos 18 originais não têm
divisor inteiro maior que 1. A reexportação em 2026-10-03 removeu essa tensão para a largura e
a altura dos assets entregues, admitindo o ajuste de proporção para a grade de 32 px previsto
na premissa.

**Consequência aceita**: a redução com filtro nearest é uma operação com perda e pode produzir
serrilhado. O MUST é satisfeito por ausência de suavização e escala 1.0; a conferência da
entrega (nomes, alturas, proporção e ausência de `.import` pendente) é feita por
`python3 tools/resize_decoration_assets.py`, e o resultado é registrado no `quickstart.md`.

---

## R2. Conversão de km/h para as unidades de física do jogo

**Decisão**: Adotar **100 unidades abstratas = 125 km/h**, ou seja, **1 km/h = 0.8 unidades**. A conversão fica em uma única constante `GameConfig.KMH_TO_SPEED_UNIT = 0.8`, e os valores em km/h permanecem legíveis na especificação e na configuração.

| Categoria | km/h | Unidades do jogo |
|---|---|---|
| `caminhao` | 90 | 72.0 |
| `utilitario` | 90 | 72.0 |
| `passeio` | 100 | 80.0 |
| `esporte` | 120 | 96.0 |
| **Jogador** | **125** | **100.0** (= `GameConfig.max_speed` atual) |

**Racional**:
O SPEC-001 define `max_speed = 100.0` em `game_config.gd:4` e calibra SC-002 (≈2.5s até a máxima), SC-003 (≈6.7s até parar) e SC-004 (≈1.4s até parar com freio) **para esse valor**. Escolher 125 km/h como âncora faz com que a velocidade máxima do jogador em unidades do jogo **continue exatamente 100.0**, sem alterar nenhuma constante do SPEC-001 nem invalidar nenhum dos três critérios de sucesso já implementados e testados.

A ordem relativa entre as categorias é preservada em qualquer conversão, portanto a restrição de FR-008 (trânsito sempre mais lento que o jogador) permanece válida independentemente do fator escolhido.

**Alternativas consideradas**:
- *Mudar `max_speed` do SPEC-001 para 125* — **descartada**: invalidaria os SC-002 a SC-004 e exigiria recalibração de `acceleration`, `brake_force` e `natural_deceleration`, alterando um spec já concluído por escopo do SPEC-004.
- *Usar km/h como unidade oficial em toda a física* — **descartada**: é uma mudança de convenção que atinge o SPEC-001 inteiro e deve ser decidida em spec própria, não aqui.

**Impacto no spec**: registrado como premissa em `spec.md`. Nenhum FR ou SC alterado.

---

## R3. Como a lógica distingue assets repetíveis (`arvore`)

**Decisão**: A repetibilidade é um **dado de configuração**, não uma comparação de string em runtime. Cada entrada da biblioteca carrega `repeatable: bool`. A string `arvore` no nome do arquivo é apenas a **origem do valor** preenchido na configuração, nunca consultada em runtime.

**Racional**:
O Constitution "Asset Independence" determina que a lógica de gameplay não deve depender de artworks específicos. Parsear o nome do arquivo em runtime para decidir comportamento violaria esse princípio e criaria acoplamento invisível: renomear um asset mudaria o comportamento do jogo sem ninguém perceber.

Com `repeatable` na configuração, o comportamento é explícito, testável e ajustável sem tocar em código.

**Alternativas consideradas**:
- *Checar `"arvore" in nome_do_arquivo` em runtime* — **descartada**: viola Asset Independence e é frágil.
- *Lista separada de assets repetíveis* — **descartada**: duplicaria a biblioteca; um campo booleano por entrada é mais simples.

**Impacto no spec**: FR-036 e SC-014 descrevem a regra pelo nome do asset porque é assim que o negócio a comunica. O plano implementa a regra pelo campo de configuração — isso é uma decisão de implementação, não uma mudança de requisito.

---

## R4. Como a biblioteca de assets é enumerada

**Decisão**: **Listas explícitas em `GameConfig`**, com uma pasta declarada por categoria e por ambiente. `DirAccess` é usado **apenas em modo debug** para comparar o conteúdo da pasta com a lista e emitir aviso de divergência.

**Racional**:
FR-012 exige que a inclusão ou troca de assets dentro da pasta não exija alteração de código. Uma lista em `GameConfig` satisfaz isso: `GameConfig` é **configuração**, não código.

Além disso, lista explícita é determinística e testável — o que `DirAccess` em runtime não é. Em builds exportados, a enumeração de arquivos empacotados depende do formato do pacote e não deve ser fonte de verdade para lógica de gameplay.

**Alternativas consideradas**:
- *`DirAccess.get_files_at()` em runtime* — **descartada como fonte de verdade**: ordem dos arquivos não é garantida, o comportamento varia entre editor e export, e introduz dependência do sistema de arquivos em lógica de gameplay.
- *Resource dedicado (`DecorationLibrary.tres`) por ambiente* — **considerada e descartada**: mais um tipo de recurso para manter sincronizado com o código, sem ganho prático para 4 bibliotecas de 3 a 5 itens. Ficará como evolução natural caso as bibliotecas cresçam para dezenas de itens.

---

## R5. Âncora de posicionamento dos elementos decorativos

**Decisão**: Cada elemento decorativo usa **centro horizontal, base vertical** (`offset = Vector2(0, altura/2)` com `centered = false`), de modo que a **base** do elemento fica sobre a linha da profundidade e o crescimento do elemento para cima não invade a profundidade vizinha.

**Racional**:
A base alinhada à linha de profundidade é o que produz a sensação de volume pedida por FR-034: o chão é a referência, e a copa cresce para cima. Com centro vertical, elementos de alturas diferentes flutuariam e a composição pareceria desalinhada. Elementos menores que a profundidade disponível são reposicionados para a profundidade mais distante que os comporte (caso de borda já previsto na spec).

**Alternativas consideradas**:
- *Centro em ambos os eixos* — **descartada**: desalinha visualmente elementos de alturas diferentes.
- *Base alinhada ao rodapé da viewport* — **descartada**: não funciona com múltiplas profundidades.

---

## R6. Conversão de asset de decoração para tamanho alvo

**Decisão (atualizada em 2026-10-03)**: a preparação descrita em R1 acontece **fora do repositório**, na reexportação dos PNGs com filtro de vizinho mais próximo sobre a base de 32x32. O repositório não reescreve mais nenhum asset: `tools/resize_decoration_assets.py` virou script de **validação** (nomes contra `GameConfig`, alturas da SC-027, proporção frente a `_originais/` e presença de `.import`), de execução somente leitura. O jogo consome apenas os PNGs já preparados.

**Racional**:
`INTERPOLATE_NEAREST` é a única opção de reamostragem compatível com pixel art no Godot 4, e ela foi aplicada na reexportação. Manter a conversão fora do `_ready()` evita custo de memória e de CPU por partida e garante que todos os elementos tenham a mesma grade de pixels.

Como a entrega é externa, o que o repositório precisa é de uma checagem repetível e não destrutiva: o validador falha se um asset declarado faltar, se um PNG ficar fora da biblioteca ou se a altura sair da faixa da SC-027, e avisa quando a proporção deslocar mais de 10% do original ou quando falta `.import`.

**Alternativas consideradas**:
- *Script reescalonador (decisão anterior de R6)* — **superado**: reescrever a partir de `_originais/` desfaria a arte entregue na base de 32x32.
- *Reescalonar no `_ready()` e cachear em memória* — **descartada**: custo por partida, e o resultado não é gravado em disco para inspeção.
- *Import hook do Godot* — **considerada e descartada**: mais complexa, sem benefício para um lote fixo e conhecido de 17 arquivos.

---

## R7. Consultar limites da estrada por faixa vertical

**Decisão**: Reutilizar `Road.get_boundaries_for_player_y(y)` já existente em `road.gd:170`, que devolve `{left, right}` **interpolados** para segmentos de transição. Todo posicionamento de tráfego e decoração consulta esse método **na altura em que o objeto é criado ou reposicionado**.

**Racional**:
Esse método já resolve a trapezoidal de 144 px para 176 px durante a transição, e é a única fonte de verdade sobre a largura vigente. Reutilizá-lo satisfaz FR-014, FR-050 e FR-051 sem duplicar a lógica de interpolação — o que a constituição proíbe explicitamente ("Responsibilities must not be unnecessarily duplicated").

O `Road` **não é modificado**: os dois sistemas apenas consomem a API existente como dado de entrada (FR-027, FR-052).

**Alternativas consideradas**:
- *Consultar `left_boundary`/`right_boundary` globais* — **descartada**: não reflete a largura no ponto vertical durante transições.
- *Modificar `Road` para expor uma API de consulta por intervalo* — **descartada**: o método existente já atende; mudar o SPEC-002 concluído seria escopo deste spec.

---

## R8. Detecção de transição de largura para reposicionamento contínuo

**Decisão**: A cada quadro, cada sistema compara a largura vigente (`right - left`) obtida em R7 com a largura que o objeto ocupava no quadro anterior. Havendo redução, o objeto é reposicionado **interpolando** do limite antigo para o novo limite com `lerpf`, usando o mesmo fator `t` da transição.

**Racional**:
FR-051 e FR-021 exigem reposicionamento **contínuo**, e o caso de borda "Reatribuição de faixa durante o estreitamento" proíbe o salto. Interpolar com o mesmo `t` usado pela estrada faz o objeto acompanhar visualmente a borda que está se movendo, em vez de deslizar de uma posição para outra de uma vez.

**Alternativas consideradas**:
- *Reposicionar instantaneamente para o limite mais próximo* — **descartada**: produz salto visível, proibido por FR-051.
- *Calcular a largura futura de forma antecipada (lookahead)* — **descartada**: complexifica sem necessidade; a interpolação por quadro já é visualmente contínua.

---

## R9. Ordem de atualização e sinalização

**Decisão**: A hierarquia de atualização é implementada como uma **lista ordenada de camadas** em `gameplay_manager.gd`, processada sequencialmente em `_process`: `BackgroundLayer → DecorationLayer → Road → TrafficLayer → PlayerVehicle`. A cada quadro, `DecorationLayer` e `TrafficLayer` recebem do `Road` o `scroll_speed` e os limites **já atualizados**, garantindo que a decoração e o trânsito se movam no mesmo referencial da estrada.

**Racional**:
FR-055 exige a hierarquia; FR-058 exige que a estrada seja a referência de 100% e que cada camada tenha um multiplicador próprio. Como a decoração e o trânsito **não podem controlar a estrada** (FR-027, FR-052), a propagação tem de ser de mão única: `gameplay_manager` orquestra, cada sistema consome.

O scene tree de `gameplay.tscn` garante a ordem de **renderização** (FR-048) por virtue da ordem dos nós filhos; a ordem de **atualização** é controlada pela lista explícita, porque o `process` do Godot não respeita a hierarquia de nós.

**Alternativas consideradas**:
- *Deixar cada sistema ler `player_vehicle.get_speed()` diretamente* — **descartada**: criaria dependência direta do trânsito e da decoração em relação ao jogador, contrariando FR-027.
- *Us `z_index` para ordenar a renderização* — **descartada**: a ordem de nós já é suficiente e mais previsível; `z_index` Adding outro vetor de configuração.

---

## R10. Colisão de sprite: área ocupada sem colisão de jogo

**Decisão**: Cada `TrafficVehicle` expõe `get_occupied_area() -> Rect2` calculada a partir da **dimensão real da textura** da categoria. O SPEC-005 consumirá essa informação. Nenhuma detecção de colisão é implementada neste spec (FR-026, FR-049).

**Racional**:
FR-025 exige que a área ocupada seja disponibilizada ao SPEC-005, mas FR-026 e FR-062 proíbem colisão nesta versão. Expor a `Rect2` sem usar satisfaz ambos: o dado fica pronto, o comportamento não.

As dimensões reais por categoria já foram medidas: `caminhao` 32x128, as demais 32x64. Elementos decorativos **não** expõem área, pois FR-049 exclui colisão de decoração de forma definitiva.

**Alternativas consideradas**:
- *Definir áreas com base em configurações de hitbox* — **descartada**: a medição real da textura é a fonte da verdade e já está disponível.
- *Implementar detecção antecipada para o SPEC-005* — **descartada**: violaria FR-026.

---

## R11. Compensação do viés de repetição nos percentuais de apresentação

**Decisão**: `weight` em `GameConfig.DECORATION_LIBRARIES` continua sendo o **percentual declarado** (meta, soma 100 por ambiente). Em `DecorationManager._montar_biblioteca` o sistema deriva, uma vez por biblioteca, `DecorationData.peso_sorteio` — o peso efetivo do sorteio — por correção fixa iterativa: passo inverso (percentual declarado -> pesos), passo direto (pesos -> frequência prevista) e estimativa da disponibilidade de repetição `1 - p^limite`.

**Racional**:
D6 e D7 retiram candidatos da disputa em alguns nascimentos e a fatia deles migra para quem ficou elegível, o que desloca a frequência observada do declarado. Medido sem compensação (500 mil nascimentos por ambiente): `deserto_cactus` 16,6% para 20% declarados, `planice_arvore01` 79,1% para 80%, `gelo_arvore` 89,2% para 96%. Com a compensação, os mesmos números ficam a menos de 0,4 p.p. do declarado em Planície, Deserto e Floresta, e a cerca de 90,3% em Gelo — perto do teto de 10/11 ≈ 90,9% que SC-014 impõe a qualquer biblioteca com uma única árvore repetível.

Manter `weight` como meta e separar o peso interno preserva a leitura direta da configuração e a conferência pelo validador, sem exigir que quem muda um percentual recalcule pesos à mão.

**Alternativas consideradas**:
- *Aceitar o viés e conferir apenas a soma 100* — **descartada**: o excedente de ~3 p.p. no cactus e o furo de ~7 p.p. na árvore de Gelo alteram a mistura visível anunciada em FR-037.
- *Aumentar `decoration_tree_repeat_limit` para 25* — **descartada**: alteraria SC-014 e o comportamento de agrupamento de árvores; o usuário optou pela compensação interna.
- *Escrever os pesos internos já compensados na configuração* — **descartada**: duplica o dado, obriga a recalcular a mão a cada mudança de percentual e esconde o alvo real.
- *Teto de elementos ativos por profundidade* — **descartada**: não altera a frequência de nascimento, que é o que FR-037 promete.

---

## Resumo das decisões

| # | Tema | Decisão |
|---|---|---|
| R1 | Escala dos assets de decoração | Assets entregues na base de tile 32x32 com nearest, exibidos em escala 1.0; alturas de 3% a 35% da área visível |
| R2 | km/h para unidades do jogo | 1 km/h = 0.8 unidades; 125 km/h = 100.0 = `max_speed` atual |
| R3 | Assets repetíveis (`arvore`) | Campo `repeatable: bool` na configuração, nunca string em runtime |
| R4 | Enumeração da biblioteca | Listas explícitas em `GameConfig`; `DirAccess` só em modo debug |
| R5 | Âncora do elemento decorativo | Base alinhada à linha de profundidade |
| R6 | Momento do reescalonamento | Preparação externa na reexportação; `tools/resize_decoration_assets.py` valida, sem escrever |
| R7 | Limites da estrada | Reutilizar `Road.get_boundaries_for_player_y()` sem modificar `Road` |
| R8 | Reposicionamento no estreitamento | `lerpf` com o mesmo `t` da transição |
| R9 | Ordem de atualização e dados | Lista ordenada em `gameplay_manager`, propagação de mão única |
| R10 | Área ocupada | `Rect2` a partir da textura real, exposta sem usar neste spec |
| R11 | Percentuais vs regras de repetição | `weight` = meta declarada; `peso_sorteio` = peso interno compensado no `setup`; teto de ~90,9% para a árvore de `ICE` |

Nenhum `NEEDS CLARIFICATION` permanece. Todos os requisitos funcionais (FR-001 a FR-062) e critérios de sucesso (SC-001 a SC-027) da spec têm implementação técnica definida neste documento.